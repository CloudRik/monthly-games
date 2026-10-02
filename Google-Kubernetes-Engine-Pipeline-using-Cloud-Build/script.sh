#!/bin/bash
# ============================================================
# Google Kubernetes Engine Pipeline using Cloud Build
# Automated Script - Multi-User Portable
# ============================================================

# ======================
# COLOR DEFINITIONS
# ======================
BOLD=$(tput bold)
RESET=$(tput sgr0)

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
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
echo "${ORANGE}${BOLD}*** Multi-User Portable Automation Script${RESET}"
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

read -p "Enter Your Region [us-central1]: " INPUT_REGION
REGION=${INPUT_REGION:-us-central1}

echo ""
echo "${YELLOW}Project ID : ${WHITE}$PROJECT_ID${RESET}"
echo "${YELLOW}Region     : ${WHITE}$REGION${RESET}"
echo ""
read -p "Proceed? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
  echo "${RED}Cancelled${RESET}"
  exit 1
fi

# ======================
# TASK 1: INITIALIZE LAB
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [1] Initializing Lab Environment${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

export PROJECT_ID=$PROJECT_ID
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=$REGION
gcloud config set compute/region $REGION

# Detect GIT_SERVER_IP
export GIT_SERVER_IP=$(gcloud compute instances describe git-server \
    --zone=$REGION-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || \
    gcloud compute instances describe git-server \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null)

if [ -z "$GIT_SERVER_IP" ]; then
    echo "${YELLOW}Could not auto-detect git-server. Please enter manually:${RESET}"
    read -p "Enter Git Server IP: " GIT_SERVER_IP
fi

echo "${GREEN}[OK] Project ID: $PROJECT_ID${RESET}"
echo "${GREEN}[OK] Project Number: $PROJECT_NUMBER${RESET}"
echo "${GREEN}[OK] Region: $REGION${RESET}"
echo "${GREEN}[OK] Git Server IP: $GIT_SERVER_IP${RESET}"
echo ""

# Enable APIs
echo "${CYAN}Enabling required APIs...${RESET}"
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    containeranalysis.googleapis.com
echo "${GREEN}[OK] APIs enabled${RESET}"
echo ""

# Create Artifact Registry
echo "${CYAN}Creating Artifact Registry repository...${RESET}"
gcloud artifacts repositories create my-repository \
    --repository-format=docker \
    --location=$REGION 2>/dev/null || echo "${YELLOW}[!] Repo may already exist${RESET}"
echo "${GREEN}[OK] Artifact Registry ready${RESET}"
echo ""

# Create GKE Cluster
echo "${CYAN}Creating GKE cluster (this takes 3-5 minutes)...${RESET}"
gcloud container clusters create hello-cloudbuild \
    --num-nodes 1 \
    --region $REGION
echo "${GREEN}[OK] GKE cluster created${RESET}"
echo ""

# Configure Git
git config --global user.name "giteaadmin"
git config --global user.email "student@qwiklabs.net"
echo "${GREEN}[OK] Git configured${RESET}"

echo "${ORANGE}${BOLD}>>> TASK 1 COMPLETE - Check my progress click karo${RESET}"

# ======================
# TASK 2: CONNECT TO GIT REPOS
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [2] Connect to Git Repositories${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

cd ~
rm -rf hello-cloudbuild-app 2>/dev/null
mkdir hello-cloudbuild-app
gcloud storage cp -r gs://spls/gsp1077/gke-gitops-tutorial-cloudbuild/* hello-cloudbuild-app
echo "${GREEN}[OK] Sample code downloaded${RESET}"

cd ~/hello-cloudbuild-app
export REGION=$REGION

sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl
echo "${GREEN}[OK] Region substituted in files${RESET}"

git init -q
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git
git branch -m main
git add . && git commit -m "initial commit" -q
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
echo "${GREEN}[OK] Pushed to Git server${RESET}"

echo "${ORANGE}${BOLD}>>> TASK 2 COMPLETE - Check my progress click karo${RESET}"

# ======================
# TASK 3: CREATE CONTAINER IMAGE
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [3] Create Container Image with Cloud Build${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

cd ~/hello-cloudbuild-app
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .
echo "${GREEN}[OK] Container image built and pushed${RESET}"

echo "${ORANGE}${BOLD}>>> TASK 3 COMPLETE - Check my progress click karo${RESET}"

# ======================
# TASK 4: CREATE CI PIPELINE
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [4] Create and Run CI Pipeline${RESET}"
echo "${ORANGE}${BOLD}====================================================${RESET}"

cd ~/hello-cloudbuild-app
git add .
git commit -m "Trigger CI pipeline" -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
echo "${GREEN}[OK] Pushed to Git${RESET}"

echo "${ORANGE}${BOLD}>>> TASK 4 COMPLETE - Check my progress click karo${RESET}"

# ======================
# TASK 5: SECRET MANAGER
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [5] Store SSH Key in Secret Manager${RESET}"
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
echo "${GREEN}[OK] Secret Manager access granted${RESET}"

echo "${ORANGE}${BOLD}>>> TASK 5 COMPLETE - Check my progress click karo${RESET}"

# ======================
# TASK 6: CD PIPELINE
# ======================
echo ""
echo "${ORANGE}${BOLD}====================================================${RESET}"
echo "${ORANGE}${BOLD}  [6] Create Test Environment & CD Pipeline${RESET}"
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

export REGION=$REGION
sed -i "s/us-central1/$REGION/g" cloudbuild.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-delivery.yaml
sed -i "s/us-central1/$REGION/g" cloudbuild-trigger-cd.yaml
sed -i "s/us-central1/$REGION/g" kubernetes.yaml.tpl
echo "${GREEN}[OK] Env repo configured${RESET}"

# Init env repo
git init -q
git remote add origin http://${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git
git branch -m main
git add . && git commit -m "initial commit" -q
git push -u http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git main
echo "${GREEN}[OK] Pushed env repo${RESET}"

# Create production and candidate branches
git checkout -b production -q
git checkout -b candidate -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git production
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
echo "${GREEN}[OK] Branches created${RESET}"

# Create cloudbuild.yaml for env repo
cd ~/hello-cloudbuild-env
cat <<'EOF' > cloudbuild.yaml
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
  - 'CLOUDSDK_COMPUTE_REGION=REGION_HERE'
  - 'CLOUDSDK_CONTAINER_CLUSTER=hello-cloudbuild'

- name: 'gcr.io/cloud-builders/gcloud'
  id: Copy to production branch
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    git clone -b production http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git prod_repo && \
    cd prod_repo && \
    git config user.email "student@qwiklabs.net" && \
    git config user.name "Cloud Build" && \
    cp ../kubernetes.yaml kubernetes.yaml && \
    git add kubernetes.yaml && \
    git commit -m "Deployed manifest from commit $_COMMIT_SHA" && \
    git push origin production

options:
  logging: CLOUD_LOGGING_ONLY
EOF

sed -i "s/REGION_HERE/$REGION/g" cloudbuild.yaml
sed -i "s/\${GIT_SERVER_IP}/$GIT_SERVER_IP/g" cloudbuild.yaml
echo "${GREEN}[OK] Env cloudbuild.yaml created${RESET}"

# Commit and push env
cd ~/hello-cloudbuild-env
git checkout candidate -q
git add cloudbuild.yaml
git commit -m "Create cloudbuild.yaml for deployment" -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
echo "${GREEN}[OK] Env cloudbuild pushed${RESET}"

# Modify CI pipeline in app repo
cd ~/hello-cloudbuild-app
cat <<'EOF' > cloudbuild.yaml
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
  - 'REGION_HERE-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:$_SHORT_SHA'
  - '.'

- name: 'gcr.io/cloud-builders/docker'
  id: Push
  args:
  - 'push'
  - 'REGION_HERE-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:$_SHORT_SHA'

- name: 'gcr.io/cloud-builders/gcloud'
  id: Clone env repo
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    git clone http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git && \
    cd hello-cloudbuild-env && \
    git checkout candidate && \
    git config user.email "student@qwiklabs.net" && \
    git config user.name "Cloud Build"

- name: 'gcr.io/cloud-builders/gcloud'
  id: Generate manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
     sed "s/GOOGLE_CLOUD_PROJECT/${PROJECT_ID}/g" kubernetes.yaml.tpl | \
     sed "s/COMMIT_SHA/${_SHORT_SHA}/g" > hello-cloudbuild-env/kubernetes.yaml

- name: 'gcr.io/cloud-builders/gcloud'
  id: Push manifest
  entrypoint: /bin/sh
  args:
  - '-c'
  - |
    set -x && \
    cd hello-cloudbuild-env && \
    git add kubernetes.yaml && \
    git commit -m "Deploying image REGION_HERE-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:${_SHORT_SHA}
    Built from commit ${_COMMIT_SHA} of repository hello-cloudbuild-app
    Author: $(git log --format='%an <%ae>' -n 1 HEAD)" && \
    git push origin candidate

options:
  logging: CLOUD_LOGGING_ONLY
EOF

sed -i "s/REGION_HERE/$REGION/g" cloudbuild.yaml
sed -i "s/\${GIT_SERVER_IP}/$GIT_SERVER_IP/g" cloudbuild.yaml
echo "${GREEN}[OK] App cloudbuild.yaml updated${RESET}"

# Commit and trigger CI
cd ~/hello-cloudbuild-app
git add cloudbuild.yaml
git commit -m "Trigger CD pipeline" -q
git push http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-app.git main
echo "${GREEN}[OK] CI pipeline triggered${RESET}"

# Pull manifest and trigger CD
cd ~/hello-cloudbuild-env
git pull http://giteaadmin:GiteaPassword123@${GIT_SERVER_IP}:3000/giteaadmin/hello-cloudbuild-env.git candidate
gcloud builds submit --config=cloudbuild.yaml --substitutions=_COMMIT_SHA=$(git rev-parse HEAD) .
echo "${GREEN}[OK] CD pipeline triggered${RESET}"

echo "${ORANGE}${BOLD}>>> TASK 6 COMPLETE - Check my progress click karo${RESET}"

# ======================
# COMPLETION
# ======================
echo ""
echo "${BG_MAGENTA}${BOLD}${WHITE}====================================================${RESET}"
echo "${BG_MAGENTA}${BOLD}${WHITE}                                                    ${RESET}"
echo "${BG_MAGENTA}${BOLD}${WHITE}         ***  LAB SUCCESSFULLY COMPLETED!  ***       ${RESET}"
echo "${BG_MAGENTA}${BOLD}${WHITE}                                                    ${RESET}"
echo "${BG_MAGENTA}${BOLD}${WHITE}====================================================${RESET}"
echo ""
echo "${WHITE}${BOLD}[>] Access your resources:${RESET}"
echo "${ORANGE}GKE Cluster: https://console.cloud.google.com/kubernetes/list?project=$PROJECT_ID${RESET}"
echo "${ORANGE}Cloud Build: https://console.cloud.google.com/cloud-build/builds?project=$PROJECT_ID${RESET}"
echo "${ORANGE}Artifact Registry: https://console.cloud.google.com/artifacts?project=$PROJECT_ID${RESET}"
echo "${ORANGE}Secret Manager: https://console.cloud.google.com/security/secret-manager?project=$PROJECT_ID${RESET}"
echo ""
echo "${CYAN}${BOLD}[i] Sab kuch ho gaya bhai! Lab panel mein check karo.${RESET}"
echo ""
