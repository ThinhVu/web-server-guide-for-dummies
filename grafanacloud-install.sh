#!/usr/bin/env sh
# shellcheck shell=dash

# This script should run in all POSIX environments and Dash is POSIX compliant.
#
# grafanacloud-install.sh installs the Grafana Agent on supported
# Linux systems for Grafana Cloud users. Those who aren't users of Grafana Cloud
# or need to install the Agent on a different architecture or platform should
# try another installation method.
#
# grafanacloud-install.sh has a hard dependency on being run on a supported
# Linux system. Currently only systems that can install deb or rpm packages
# are supported. The target system will try to be detected, but if it cannot,
# PACKAGE_SYSTEM can be passed as an environment variable with either rpm or
# deb.

set -eu
trap "exit 1" TERM
MY_PID=$$

log() {
  echo "$@" >&2
}

fatal() {
  log "$@"
  kill -s TERM "${MY_PID}"
}

# detect_arch tries to determine the cpu architecture. The output must be
# one of the supported agent build architectures for deb and rpm packages.
detect_arch() {
  uname_m=$(uname -m)
  case "${uname_m}" in
    amd64|x86_64)
      echo "amd64"
      return
      ;;
    aarch64|arm64*)
      echo "arm64"
      return
      ;;
    ppc64el|ppc64le)
      echo "${uname_m}"
      return
      ;;
    *)
      fatal "Unknown unsupported arch: ${uname_m}"
      ;;
  esac
}

# detect_package_system tries to detect the host distribution to determine if
# deb or rpm should be used for installing the Agent. Prints out either "deb"
# or "rpm". Calls fatal if the host OS is not supported.
detect_package_system() {
  command -v dpkg >/dev/null 2>&1 && { echo "deb"; return; }
  command -v rpm  >/dev/null 2>&1 && { echo "rpm"; return; }

  uname=$(uname)
  case "${uname}" in
    Darwin)
      fatal 'macOS not supported'
      ;;
    *)
      fatal "Unknown unsupported OS: ${uname}"
      ;;
  esac
}

SHA256_SUMS="
# BEGIN_SHA256_SUMS
11f36ef18dae837087234f6122cae3b88480e604fb8eaf8311f54c2fad813997  grafana-agent-0.38.1-1.amd64.deb
8bb6848d6519e896f1aeb93361781ca3bff2e040216a8b8186392d23c2a28c11  grafana-agent-0.38.1-1.amd64.rpm
861bad19f2360d226c648d5800eca893bbe7caeb39ec094223bbeb4e0258403c  grafana-agent-0.38.1-1.arm64.deb
36329e0bfc4e49c5aebaeb6dc9238e97b90b3075931f9420bfa6165ca4a8f43c  grafana-agent-0.38.1-1.arm64.rpm
6820beecab3eae80d5817d2a2dbca828b768f783d77fdf6af22f872e407ef278  grafana-agent-0.38.1-1.ppc64el.deb
0f007893d8b0c09d8fd4f032942a514a8841f53fb2bfa045ad6d6086e0d3e764  grafana-agent-0.38.1-1.ppc64le.rpm
6e34a2f267093e4f3d923788f2c6ff4ce766988404cae4670d58cfd4975f7a75  grafana-agent-0.38.1-1.s390x.deb
d38e41b41ec3017f695450e85a09dd36bfcd01e43f8f8a26ec155db15ee7777a  grafana-agent-0.38.1-1.s390x.rpm
7b48022cca2cbb1b98e634eb00633981c77eec8de88e721c36377bb17be5d7be  grafana-agent-flow-0.38.1-1.amd64.deb
9442574ea1d067d6cdaf4c396611e022f9f45fd15d9f124ea6e9f853747b6ab6  grafana-agent-flow-0.38.1-1.amd64.rpm
9738e134aaebebe5381c74006f2e4ef37091f05ff5c426135902b2c1efb1ed9e  grafana-agent-flow-0.38.1-1.arm64.deb
240de849993495504228aad6ef655adb36a507e759203d3beb0ac9e5e82bb6a8  grafana-agent-flow-0.38.1-1.arm64.rpm
282b18e86461e697c9ea045580221c35d58b72be93571b9d483062520013ca96  grafana-agent-flow-0.38.1-1.ppc64el.deb
720324a57c37957b08df7200daf1517e810e6d85bc911de8fbea92e32deedc7d  grafana-agent-flow-0.38.1-1.ppc64le.rpm
db968f785ecc5a4edaab06485cac83fce22b817338a39bdfeee0ac5ef5a8facc  grafana-agent-flow-0.38.1-1.s390x.deb
e82f96ecdbe136cc735199df8f84c4a11a2fe78fe62b8c07fbd18977ae8d1631  grafana-agent-flow-0.38.1-1.s390x.rpm
# END_SHA256_SUMS
"

#
# REQUIRED environment variables.
#
GCLOUD_HOSTED_METRICS_URL=${GCLOUD_HOSTED_METRICS_URL:=}   # Grafana Cloud Hosted Metrics url
GCLOUD_HOSTED_METRICS_ID=${GCLOUD_HOSTED_METRICS_ID:=}     # Grafana Cloud Hosted Metrics Instance ID
GCLOUD_SCRAPE_INTERVAL=${GCLOUD_SCRAPE_INTERVAL:=}         # Grafana Cloud Hosted Metrics scrape interval
GCLOUD_HOSTED_LOGS_URL=${GCLOUD_HOSTED_LOGS_URL:=}         # Grafana Cloud Hosted Logs url
GCLOUD_HOSTED_LOGS_ID=${GCLOUD_HOSTED_LOGS_ID:=}           # Grafana Cloud Hosted Logs Instance ID
GCLOUD_RW_API_KEY=${GCLOUD_RW_API_KEY:=}                   # Grafana Cloud API key

[ -z "${GCLOUD_HOSTED_METRICS_URL}" ] && fatal "Required environment variable \$GCLOUD_HOSTED_METRICS_URL not set."
[ -z "${GCLOUD_HOSTED_METRICS_ID}" ]  && fatal "Required environment variable \$GCLOUD_HOSTED_METRICS_ID not set."
[ -z "${GCLOUD_SCRAPE_INTERVAL}" ]  && fatal "Required environment variable \$GCLOUD_SCRAPE_INTERVAL not set."
[ -z "${GCLOUD_HOSTED_LOGS_URL}" ] && fatal "Required environment variable \$GCLOUD_HOSTED_LOGS_URL not set."
[ -z "${GCLOUD_HOSTED_LOGS_ID}" ]  && fatal "Required environment variable \$GCLOUD_HOSTED_LOGS_ID not set."
[ -z "${GCLOUD_RW_API_KEY}" ]  && fatal "Required environment variable \$GCLOUD_RW_API_KEY not set."

#
# OPTIONAL environment variables.
#

# Architecture to install. If empty, the script will try to detect the value to use.
ARCH=${ARCH:=$(detect_arch)}

# Package system to install the Agent with. If not empty, MUST be either rpm or
# deb. If empty, the script will try to detect the host OS and the appropriate
# package system to use.
PACKAGE_SYSTEM=${PACKAGE_SYSTEM:=$(detect_package_system)}

#
# Global constants.
#
RELEASE_VERSION="v0.38.1"
GRAFANA_AGENT_CONFIG="https://storage.googleapis.com/cloud-onboarding/agent/config/config.yaml"
RELEASE_URL="https://github.com/grafana/agent/releases/download/${RELEASE_VERSION}"

main() {
  log "--- Using package system ${PACKAGE_SYSTEM}. Downloading and installing package for ${ARCH}"

  case "${PACKAGE_SYSTEM}" in
    deb)
      install_deb
      ;;
    rpm)
      install_rpm
      ;;
    *)
      fatal "Could not detect a valid Package Management System. Must be either RPM or dpkg"
      ;;
  esac

  log '--- Retrieving config and placing in /etc/grafana-agent.yaml'
  download_config

  log '--- Enabling and starting grafana-agent.service'
  systemctl enable grafana-agent.service
  systemctl start grafana-agent.service

  log ''
  log ''
  log 'Grafana Agent is now running!'
  log ''
  log 'To check the status of your Agent, run:'
  log '   systemctl status grafana-agent.service'
  log ''
  log 'To restart the Agent, run:'
  log '   systemctl restart grafana-agent.service'
  log ''
  log 'The config file is located at:'
  log '   /etc/grafana-agent.yaml'
}

# install_deb downloads and installs the deb package of the Grafana Agent.
install_deb() {
  # The DEB and RPM urls don't include the `v` version prefix in the file names,
  # so we trim it out using ${RELEASE_VERSION#v} below.
  DEB_NAME="grafana-agent-${RELEASE_VERSION#v}-1.${ARCH}.deb"
  DEB_URL="${RELEASE_URL}/${DEB_NAME}"
  CURL_PATH=$(command -v curl)

  curl -fL# "${DEB_URL}" -o "/tmp/${DEB_NAME}" || fatal 'Failed to download package'

  case "${CURL_PATH}" in
    /snap/bin/curl)
      log '--'
      log '--- WARNING: curl installed via snap may not store downloaded file'
      log '--- If checksum of package fails, use apt to install curl'
      log '---'
      ;;
    *)
      ;;
  esac
  log '--- Verifying package checksum'
  check_sha
  dpkg -i "/tmp/${DEB_NAME}"
  rm "/tmp/${DEB_NAME}"
}

# install_rpm downloads and installs the rpm package of the Grafana Agent.
install_rpm() {
  # The DEB and RPM urls don't include the `v` version prefix in the file names,
  # so we trim it out using ${RELEASE_VERSION#v} below.
  RPM_NAME="grafana-agent-${RELEASE_VERSION#v}-1.${ARCH}.rpm"
  RPM_URL="${RELEASE_URL}/${RPM_NAME}"

  curl -fL# "${RPM_URL}" -o "/tmp/${RPM_NAME}" || fatal 'Failed to download package'
  log '--- Verifying package checksum'
  check_sha
  rpm --reinstall "/tmp/${RPM_NAME}"
  rm "/tmp/${RPM_NAME}"
}

# download_config downloads the config file for the Agent and replaces
# placeholders with actual values.
download_config() {
  curl -fsSL "${GRAFANA_AGENT_CONFIG}" -o /tmp/grafana-agent.yaml || fatal 'Failed to download config'
  sed -i -e "s~{GCLOUD_RW_API_KEY}~${GCLOUD_RW_API_KEY}~g" /tmp/grafana-agent.yaml
  sed -i -e "s~{GCLOUD_HOSTED_METRICS_URL}~${GCLOUD_HOSTED_METRICS_URL}~g" /tmp/grafana-agent.yaml
  sed -i -e "s~{GCLOUD_HOSTED_METRICS_ID}~${GCLOUD_HOSTED_METRICS_ID}~g" /tmp/grafana-agent.yaml
  sed -i -e "s~{GCLOUD_SCRAPE_INTERVAL}~${GCLOUD_SCRAPE_INTERVAL}~g" /tmp/grafana-agent.yaml
  sed -i -e "s~{GCLOUD_HOSTED_LOGS_URL}~${GCLOUD_HOSTED_LOGS_URL}~g" /tmp/grafana-agent.yaml
  sed -i -e "s~{GCLOUD_HOSTED_LOGS_ID}~${GCLOUD_HOSTED_LOGS_ID}~g" /tmp/grafana-agent.yaml
  mv /tmp/grafana-agent.yaml /etc/grafana-agent.yaml
}

check_sha() {
  cd /tmp
  echo -n "${SHA256_SUMS}" | sha256sum -c - 2>&1 | grep "OK" || fatal 'Failed sha256sum check'
  cd "${OLDPWD}"
}

main
