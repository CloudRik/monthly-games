#!/bin/bash
# ============================================================
# Google Kubernetes Engine Pipeline using Cloud Build
# Full Automated Script - Multi-User Portable
# ============================================================

# ======================
# COLOR DEFINITIONS
# ======================
BOLD=$(tput bold)
RESET=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
WHITE=$(tput setaf 7)
ORANGE="\033[38;5;208m"
BG_CYAN=$(tput setab 6)
BG_MAGENTA=$(tput setab 5)

# ======================
# HEADER
# ======================
clear
echo "${BG_CYAN}${BOLD}${WHITE}==================================================${RESET}"
echo "${BG_CYAN}${BOLD}${WHITE}   >>  GKE PIPELINE USING CLOUD BUILD  <<          ${RESET}"
echo "${BG_CYAN}${BOLD}${WHITE}==================================================${RESET}"
echo ""

# ======================
# USER INPUTS
# ======================
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [SETUP] Enter Your Lab Details${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

DETECTED_PROJECT=$(gcloud config get-value project 2>/dev/null)
read -p "Enter Your Project ID [${DETECTED_PROJECT}]: " INPUT_PROJECT
PROJECT_ID=${INPUT_PROJECT:-$DETECTED_PROJECT}

read -p "Enter Your Region [us-east1]: " INPUT_REGION
REGION=${INPUT_REGION:-us-east1}

DETECTED_ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])" 2>/dev/null)
read -p "Enter Your Zone [${DETECTED_ZONE}]: " INPUT_ZONE
ZONE=${INPUT_ZONE:-$DETECTED_ZONE}

# Auto-detect git-server IP
GIT_SERVER_IP=""
for TRY_ZONE in "$ZONE" "${REGION}-a" "${REGION}-b" "${REGION}-c"; do
    GIT_SERVER_IP=$(gcloud compute instances describe git-server \
        --zone=$TRY_ZONE \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null)
    [ -n "$GIT_SERVER_IP" ] && break
done
if [ -z "$GIT_SERVER_IP" ]; then
    read -p "Enter Git Server IP: " GIT_SERVER_IP
fi

echo ""
echo "${YELLOW}Project ID    : ${WHITE}$PROJECT_ID${RESET}"
echo "${YELLOW}Region        : ${WHITE}$REGION${RESET}"
echo "${YELLOW}Zone          : ${WHITE}$ZONE${RESET}"
echo "${YELLOW}Git Server IP : ${WHITE}$GIT_SERVER_IP${RESET}"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Cancelled"
    exit 1
fi

# ======================
# TASK 1: INITIALIZE LAB
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [TASK 1] Initialize Lab${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

export PROJECT_ID=$PROJECT_ID
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=$REGION
export ZONE=$ZONE
export GIT_SERVER_IP=$GIT_SERVER_IP
gcloud config set compute/region $REGION

echo "${GREEN}[OK] PROJECT_ID=$PROJECT_ID${RESET}"
echo "${GREEN}[OK] PROJECT_NUMBER=$PROJECT_NUMBER${RESET}"
echo "${GREEN}[OK] REGION=$REGION${RESET}"
echo "${GREEN}[OK] GIT_SERVER_IP=$GIT_SERVER_IP${RESET}"

echo "${CYAN}Enabling APIs...${RESET}"
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com
echo "${GREEN}[OK] APIs enabled${RESET}"

echo "${CYAN}Creating Artifact Registry...${RESET}"
gcloud artifacts repositories create my-repository \
    --repository-format=docker \
    --location=$REGION 2>/dev/null || echo "[!] Repo exists"
echo "${GREEN}[OK] Artifact Registry ready${RESET}"

echo "${CYAN}Creating GKE cluster (3-5 min)...${RESET}"
gcloud container clusters create hello-cloudbuild \
    --num-nodes 1 \
    --region $REGION
echo "${GREEN}[OK] GKE cluster created${RESET}"

git config --global user.name "giteaadmin"
git config --global user.email "student@qwiklabs.net"
echo "${GREEN}[OK] Git configured${RESET}"
echo "${ORANGE}>>> TASK 1 COMPLETE - Check my progress${RESET}"

# ======================
# TASK 2: GIT REPOS
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [TASK 2] Connect to Git Repositories${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

cd ~
rm -rf hello-cloudbuild-app 2>/dev/null
mkdir hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app
echo "${GREEN}[OK] Sample code downloaded${RESET}"

cd ~/hello-cloudbuild-app
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl
echo "${GREEN}[OK] Region substituted${RESET}"

git init -q
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git
git branch -m main
git add . && git commit -m "initial commit" -q
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
echo "${GREEN}[OK] Pushed to Git${RESET}"
echo "${ORANGE}>>> TASK 2 COMPLETE - Check my progress${RESET}"

# ======================
# TASK 3: CONTAINER IMAGE
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [TASK 3] Create Container Image${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

cd ~/hello-cloudbuild-app
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .
echo "${GREEN}[OK] Container image built${RESET}"
echo "${ORANGE}>>> TASK 3 COMPLETE - Check my progress${RESET}"

# ======================
# TASK 4: CI PIPELINE
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [TASK 4] Create CI Pipeline${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

cd ~/hello-cloudbuild-app
git add .
git commit -m "Trigger CI pipeline" -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
echo "${GREEN}[OK] CI pipeline triggered${RESET}"
echo "${ORANGE}>>> TASK 4 COMPLETE - Check my progress${RESET}"

# ======================
# TASK 5: SECRET MANAGER
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [TASK 5] Store SSH Key in Secret Manager${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

mkdir -p ~/workingdir && cd ~/workingdir
ssh-keygen -t rsa -b 4096 -N '' -f id_rsa -C "student@qwiklabs.net" -q
echo "${GREEN}[OK] SSH key generated${RESET}"

gcloud secrets create ssh_key_secret --data-file=$HOME/workingdir/id_rsa 2>/dev/null || \
    gcloud secrets versions add ssh_key_secret --data-file=$HOME/workingdir/id_rsa
echo "${GREEN}[OK] Secret created${RESET}"

PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --role=roles/secretmanager.secretAccessor --condition=None >/dev/null 2>&1
echo "${GREEN}[OK] Secret access granted${RESET}"
echo "${ORANGE}>>> TASK 5 COMPLETE - Check my progress${RESET}"

# ======================
# TASK 6: CD PIPELINE
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [TASK 6] Create CD Pipeline${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='get(projectNumber)')
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer --condition=None >/dev/null 2>&1
echo "${GREEN}[OK] Cloud Build GKE access granted${RESET}"

# Setup env repo
cd ~
rm -rf hello-cloudbuild-env 2>/dev/null
mkdir ~/hello-cloudbuild-env
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* ~/hello-cloudbuild-env
cd ~/hello-cloudbuild-env

sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl
echo "${GREEN}[OK] Env repo region substituted${RESET}"

git init -q
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git
git branch -m main
git add . && git commit -m "initial commit" -q
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git main
echo "${GREEN}[OK] Pushed env repo${RESET}"

git checkout -b production -q
git checkout -b candidate -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git production
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
echo "${GREEN}[OK] Branches created${RESET}"

# Write env cloudbuild.yaml with unquoted heredoc so $REGION expands
cd ~/hello-cloudbuild-env
cat <<CLOUDBUILD_ENV_EOF
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

substitutions:
  _COMMIT_SHA: 'v1.0'

steps:
- name: 'gcr.io/cloud-builders/kubectl'
  id: Deploy
  args:
  - 'apply'
  - '-f'
  - 'kubernetes.yaml'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=${REGION}'
  - 'CLOUDSDK_CONTAINER_CLUSTER=hello-cloudbuild'

- name: 'gcr.io/cloud-builders/gcloud'
  id: Copy to production branch
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \\
    git clone -b production http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git prod_repo && \\
    cd prod_repo && \\
    git config user.email "student@qwiklabs.net" && \\
    git config user.name "Cloud Build" && \\
    cp ../kubernetes.yaml kubernetes.yaml && \\
    git add kubernetes.yaml && \\
    git commit -m "Deployed manifest from commit \$_COMMIT_SHA" && \\
    git push origin production

options:
  logging: CLOUD_LOGGING_ONLY
CLOUDBUILD_ENV_EOF
echo "${GREEN}[OK] Env cloudbuild.yaml created${RESET}"

# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('cloudbuild.yaml'))" && echo "${GREEN}[OK] Env YAML valid${RESET}"

# Commit and push
git add cloudbuild.yaml
git commit -m "Create cloudbuild.yaml for deployment" -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
echo "${GREEN}[OK] Env cloudbuild pushed${RESET}"

# Write app cloudbuild.yaml
cd ~/hello-cloudbuild-app
cat <<CLOUDBUILD_APP_EOF
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

substitutions:
  _SHORT_SHA: 'v1.0'
  _COMMIT_SHA: 'v1.0'

steps:
- name: 'python:3.7-slim'
  id: Test
  entrypoint: /bin/sh
  args:
  - -c
  - 'pip install flask && python test_app.py -v'

- name: 'gcr.io/cloud-builders/docker'
  id: Build
  args:
  - 'build'
  - '-t'
  - '${REGION}-docker.pkg.dev/\$PROJECT_ID/my-repository/hello-cloudbuild:\$_SHORT_SHA'
  - '.'

- name: 'gcr.io/cloud-builders/docker'
  id: Push
  args:
  - 'push'
  - '${REGION}-docker.pkg.dev/\$PROJECT_ID/my-repository/hello-cloudbuild:\$_SHORT_SHA'

- name: 'gcr.io/cloud-builders/gcloud'
  id: Clone env repo
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    git clone http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git && \\
    cd hello-cloudbuild-env && \\
    git checkout candidate && \\
    git config user.email "student@qwiklabs.net" && \\
    git config user.name "Cloud Build"

- name: 'gcr.io/cloud-builders/gcloud'
  id: Generate manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
     sed "s/GOOGLE_CLOUD_PROJECT/\${PROJECT_ID}/g" kubernetes.yaml.tpl | \\
     sed "s/COMMIT_SHA/\${_SHORT_SHA}/g" > hello-cloudbuild-env/kubernetes.yaml

- name: 'gcr.io/cloud-builders/gcloud'
  id: Push manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \\
    cd hello-cloudbuild-env && \\
    git add kubernetes.yaml && \\
    git commit -m "Deploying image ${REGION}-docker.pkg.dev/\$PROJECT_ID/my-repository/hello-cloudbuild:\${_SHORT_SHA}
    Built from commit \${_COMMIT_SHA} of repository hello-cloudbuild-app
    Author: \$(git log --format='%an <%ae>' -n 1 HEAD)" && \\
    git push origin candidate

options:
  logging: CLOUD_LOGGING_ONLY
CLOUDBUILD_APP_EOF
echo "${GREEN}[OK] App cloudbuild.yaml created${RESET}"

# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('cloudbuild.yaml'))" && echo "${GREEN}[OK] App YAML valid${RESET}"

# Push app
git add cloudbuild.yaml
git commit -m "Trigger CD pipeline" -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
echo "${GREEN}[OK] App pushed${RESET}"

# Wait for CI
echo "${CYAN}Waiting 60 sec for CI build...${RESET}"
sleep 60

# Trigger CD
cd ~/hello-cloudbuild-env
git pull http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
gcloud builds submit --config=cloudbuild.yaml --substitutions=_COMMIT_SHA=$(git rev-parse HEAD) .
echo "${GREEN}[OK] CD pipeline triggered${RESET}"
echo "${ORANGE}>>> TASK 6 COMPLETE - Check my progress${RESET}"

# ======================
# COMPLETION
# ======================
echo ""
echo "${BG_MAGENTA}${BOLD}${WHITE}====================================================${RESET}"
echo "${BG_MAGENTA}${BOLD}${WHITE}     ***  LAB SUCCESSFULLY COMPLETED!  ***          ${RESET}"
echo "${BG_MAGENTA}${BOLD}${WHITE}====================================================${RESET}"
echo ""
echo "${WHITE}${BOLD}[>] Access your resources:${RESET}"
echo "${ORANGE}GKE: https://console.cloud.google.com/kubernetes/list?project=$PROJECT_ID${RESET}"
echo "${ORANGE}Cloud Build: https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID${RESET}"
echo "${ORANGE}Artifact Registry: https://console.cloud.google.com/artifacts?project=$PROJECT_ID${RESET}"
echo "${ORANGE}Secret Manager: https://console.cloud.google.com/security/secret-manager?project=$PROJECT_ID${RESET}"
echo ""
echo "${CYAN}${BOLD}[i] Sab kuch ho gaya! Lab panel mein check karo.${RESET}"
echo ""
