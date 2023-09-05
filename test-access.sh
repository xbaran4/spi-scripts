#!/bin/bash
set -e

GITHUB_PAT="ghp_xxxxxxx"
GITLAB_PAT="glpat-xxxxxx"
QUAY_ROBOT_NAME="pbaran+test"
QUAY_ROBOT_TOKEN="ABCDEGH"
source tokens.sh # replace your tokens here

GITHUB_PRIVATE_REPO="https://github.com/xbaran4/testing"
GITLAB_PRIVATE_REPO="https://gitlab.com/xbaran4/test"
QUAY_PRIVATE_REPO="https://quay.io/pbaran/private-test"

GITHUB_PUBLIC_REPO="https://github.com/xbaran4/remote-secret"
GITLAB_PUBLIC_REPO="https://gitlab.com/xbaran4/public-test"
QUAY_PUBLIC_REPO="https://quay.io/pbaran/rs"

SPI_REPO_PATH="$HOME/workplace/spi-operator/"

kubectl apply -f "${SPI_REPO_PATH}/hack/give-default-sa-perms-for-accesstokens.yaml"
AUTH_TOKEN=$("${SPI_REPO_PATH}/hack/get-default-sa-token.sh")
BASE_URL=$(kubectl get cm/spi-shared-environment-config -n spi-system -o yaml | yq .data.BASEURL)


echo "Checking access to public repositories without any tokens..."
for i in $GITHUB_PUBLIC_REPO $GITLAB_PUBLIC_REPO $QUAY_PUBLIC_REPO; do
echo "Checking repository:" ${i}
cat <<EOF | kubectl apply -f -
apiVersion: appstudio.redhat.com/v1beta1
kind: SPIAccessCheck
metadata:
  name: spiaccesscheck-public-test
spec:
  repoUrl: "${i}"
EOF
kubectl wait --for=jsonpath='{status.accessible}'=true spiaccesscheck/spiaccesscheck-public-test
kubectl wait --for=jsonpath='{status.accessibility}'=public spiaccesscheck/spiaccesscheck-public-test
kubectl delete spiaccesscheck/spiaccesscheck-public-test
done
echo "Done."
echo


echo "Creating SPIAccessTokens for each provider to test private repo..."
for i in "github.com ${GITHUB_PAT} gibberish repository" "gitlab.com ${GITLAB_PAT} gibberish repository" "quay.io ${QUAY_ROBOT_TOKEN} ${QUAY_ROBOT_NAME} registry"; do
  set -- $i
cat <<EOF | kubectl apply -f -
apiVersion: appstudio.redhat.com/v1beta1
kind: SPIAccessToken
metadata:
  name: test-access-token-${1}
  namespace: default
spec:
  permissions:
    required:
      - type: w
        area: ${4}
  serviceProviderUrl: https://${1}
EOF
curl --insecure -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -d "{\"username\": \"${3}\", \"access_token\": \"${2}\"}" "${BASE_URL}/token/default/test-access-token-${1}"
done
sleep 10
echo "Done."
echo


echo "Checking access to private repositories with SPIAccessToken..."
for i in $GITHUB_PRIVATE_REPO $GITLAB_PRIVATE_REPO $QUAY_PRIVATE_REPO; do
echo "Checking repository:" ${i}
cat <<EOF | kubectl apply -f -
apiVersion: appstudio.redhat.com/v1beta1
kind: SPIAccessCheck
metadata:
  name: spiaccesscheck-private-test
spec:
  repoUrl: "${i}"
EOF
kubectl wait --for=jsonpath='{status.accessible}'=true spiaccesscheck/spiaccesscheck-private-test
kubectl wait --for=jsonpath='{status.accessibility}'=private spiaccesscheck/spiaccesscheck-private-test
kubectl delete spiaccesscheck/spiaccesscheck-private-test
done
echo "Done."
echo

echo "Removing SPIAccessTokens..."
for i in github.com gitlab.com quay.io; do
 kubectl delete spiaccesstoken/test-access-token-${i}
done
echo "Done."
echo


echo "Creating RemoteSecrets and UploadSecrets for each provider to test private repo..."
for i in "github.com ${GITHUB_PAT}" "gitlab.com ${GITLAB_PAT}" "quay.io ${QUAY_ROBOT_TOKEN} ${QUAY_ROBOT_NAME}"; do
  set -- $i
cat <<EOF | kubectl apply -f -
apiVersion: appstudio.redhat.com/v1beta1
kind: RemoteSecret
metadata:
  name: test-remote-secret-${1}
  namespace: default
  labels:
    appstudio.redhat.com/sp.host: ${1}
spec:
  secret:
    type: kubernetes.io/basic-auth
    name: secret-from-remote-${1}
  targets:
  - namespace: default
EOF
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: test-remote-secret-secret
  labels:
    appstudio.redhat.com/upload-secret: remotesecret
  annotations:
    appstudio.redhat.com/remotesecret-name: test-remote-secret-${1}
type: kubernetes.io/basic-auth
stringData:
  username: ${3}
  password: ${2}
EOF
done
sleep 10
echo "Done."
echo


echo "Checking access to private repositories with RemoteSecret..."
for i in $GITHUB_PRIVATE_REPO $GITLAB_PRIVATE_REPO $QUAY_PRIVATE_REPO; do
echo "Checking repository:" ${i}
cat <<EOF | kubectl apply -f -
apiVersion: appstudio.redhat.com/v1beta1
kind: SPIAccessCheck
metadata:
  name: spiaccesscheck-private-test
spec:
  repoUrl: "${i}"
EOF
kubectl wait --for=jsonpath='{status.accessible}'=true spiaccesscheck/spiaccesscheck-private-test
kubectl wait --for=jsonpath='{status.accessibility}'=private spiaccesscheck/spiaccesscheck-private-test
kubectl delete spiaccesscheck/spiaccesscheck-private-test
done
echo "Done."
echo

echo "Removing RemoteSecrets..."
for i in github.com gitlab.com quay.io; do
 kubectl delete remotesecret/test-remote-secret-${i}
done
echo "Done."
echo

echo "TEST: PASSED"
