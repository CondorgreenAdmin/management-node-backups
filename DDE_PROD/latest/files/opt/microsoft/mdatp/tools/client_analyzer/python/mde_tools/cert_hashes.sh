#!/bin/bash

# Directory containing the certificate files

WDAVENGINE_PATH=$1
if [ -z "$WDAVENGINE_PATH" ]; then
  WDAVENGINE_PATH="/var/opt/microsoft/mdatp/wdavengine"
fi

known_cert_stores=("/var/ssl/certs" "/etc/ssl/certs" "/etc/openssl/certs" "/etc/pki/tls/certs" "/etc/ca-certificates" "/usr/local/share/certs" "/usr/share/ca-certificates" "/usr/share/pki/trust/anchors" "/usr/local/share/ca-certificates" "/etc/pki/ca-trust/source/anchors")

process_certificates_from_dir() {
CERT_DIR="$1"
# Check if the directory exists
if [ ! -d "$CERT_DIR" ]; then
  echo "Directory $CERT_DIR does not exist."
  return 
fi
ls -ltrh "$CERT_DIR"

# Iterate over all certificate files in the directory
for cert in "$CERT_DIR"/*; do
  local subject_hash
  local subject_hash_status
  local sha256_hash
  local sha256_hash_status
  local sha512_hash
  local sha512_hash_status
  local sha1_hash
  local sha1_hash_status

  # Ensure it's a file
  if [ -f "$cert" ]; then
    echo "Processing certificate: $cert"

    # Compute subject hash
    subject_hash=$(openssl x509 -in "$cert" -noout -subject_hash 2> /dev/null )
    subject_hash_status=$? 
    if [ $subject_hash_status -ne 0 ]; then
      echo "Failed to get subject hash for file $cert" | tee /dev/stderr
    else
      if [ -n "$subject_hash" ]; then
        echo "$cert --  subject_hash  -- $subject_hash"
      fi
    fi

    # Compute SHA-256 hash
    sha256_hash=$(openssl x509 -in "$cert" -noout -fingerprint -sha256   2> /dev/null | sed 's/://g' | awk -F= '{print $2}')
    sha256_hash_status=$?
    if [ $sha256_hash_status -ne 0 ]; then
      echo "Failed to get fingerprint sha256 for file $cert" | tee /dev/stderr
    else
      if [ -n "$sha256_hash" ]; then
        echo "$cert --  sha256_hash -- $sha256_hash"
      fi
    fi

    # Compute SHA-512 hash
    sha512_hash=$(openssl x509 -in "$cert" -noout -fingerprint -sha512  2> /dev/null | sed 's/://g' | awk -F= '{print $2}')
    sha512_hash_status=$?
    if [ $sha512_hash_status -ne 0 ]; then
      echo "Failed to get fingerprint sha512 for file $cert" | tee /dev/stderr
    else
      if [ -n "$sha512_hash" ]; then
        echo "$cert --  sha512_hash -- $sha512_hash"
      fi
    fi

    sha1_hash=$(openssl x509 -in "$cert" -noout -fingerprint -sha1  2> /dev/null | sed 's/://g' | awk -F= '{print $2}')
    sha1_hash_status=$?
    if [ $sha1_hash_status -ne 0 ]; then
      echo "Failed to get fingerprint sha1 for file $cert" | tee /dev/stderr
    else
      if [ -n "$sha1_hash" ]; then
        echo "$cert --  sha1_hash -- $sha1_hash"
      fi
    fi

    echo ""
  fi
done
}

if ! command -v openssl &> /dev/null
then
    echo "ERROR: openssl not found on system, please install openssl on system before running this option" >&2
    exit 1
fi

for cert_store in "${known_cert_stores[@]}"; do
  echo "Processing known_cert_store dir $cert_store =====================START==========================="
  process_certificates_from_dir "$cert_store"
  echo "Processing known_cert_store dir $cert_store =====================END==========================="
done

# JSON string
json_string=$(cat $WDAVENGINE_PATH)
#json_string='{"certStores":["/etc/ssl/certs","/etc/ssl/certs1","/usr/local/share/ca-certificates"],"databaseCreationTime":"1720516448000","databaseInstallationTime":"1721035771665","databaseVersion":27197450,"engineLoadStatus":"Engine load succeeded","engineVersion":"1.1.24070.64027","fullDatabaseVersion":"1.415.10.0","licenseExpirationTime":"4294967295000","networkProtectionSignatureControls":{"networkProtectionAutoExclusions":[],"networkProtectionNriSuppressionList":[],"networkProtectionRemoteSettings":{"allowRiskyFeaturesDisable":true,"allowSwitchToAsync":true,"crashCountTolerance":5,"disableIcmpInspection":true,"disableNetworkProtectionAudit":false,"disableNetworkProtectionBlock":false,"disableSmtpInspection":true,"enableBugfix49119667":true,"enableConvertWarnToBlock":true,"enableDisconnectedChange":true,"enableHealthCheckReset":true,"enableHealthCheckResetClean":true,"enableInspectResourceAssignment":false,"enableKernelVolumeQueries":false,"enableNpPerfReporting":false,"enableNriMpengineMetadata":true,"enableSelfHealTelemetry":false,"enableUrlrepDurationTelemetry":false,"enableUroSupport":true,"enableUsoSupport":false,"enableVerdictCallbackMode":false,"kernelVolumeQueryFrequency":0,"maxVolumeEvents":"10","reputationMode":"v0","sendVolumeUpdates":false,"signatureAgeTolerance":48,"useVerdict":false,"volumeEventFrequency":30,"volumeTelemetryTimeout":60}},"numberOfSignatures":"949504","productVersion":"1.0.0","trustAnchorConfiguration":[{"environment":"XplatTesting","hashType":0,"intThumbs":["83688F2AEF71386E0936C4B3013B07E8E0C796D8427716DD48B2A63D79509129"],"rootThumbs":["847DF6A78497943F27FC72EB93F9A637320A02B561D0A91B09E87A7807ED7C61","9BD0F7CF6ED967519391BCD49A958867B955A60F22DE5B8978474A2FCBAD81A6"],"usage":2,"version":"1"},{"environment":"XplatTesting","hashType":0,"intThumbs":["83688F2AEF71386E0936C4B3013B07E8E0C796D8427716DD48B2A63D79509129"],"rootThumbs":["847DF6A78497943F27FC72EB93F9A637320A02B561D0A91B09E87A7807ED7C61","9BD0F7CF6ED967519391BCD49A958867B955A60F22DE5B8978474A2FCBAD81A6"],"usage":1,"version":"1"}]}'

echo "Content of wdaveng is $json_string"
echo ""
configured_cert_stores=$(echo "$json_string" | grep -o '"certStores":\[[^]]*\]' | sed 's/"certStores":\[\(.*\)\]/\1/'| sed 's/"//g')
echo "configured_cert_stores from wdaveng is $configured_cert_stores"

IFS=','
read -ra values <<< "$configured_cert_stores"
for cert_store in "${values[@]}"; do
  echo "Processing configured_cert_stores dir $cert_store =====================START==========================="
  process_certificates_from_dir "$cert_store"
  echo "Processing configured_cert_stores dir $cert_store =====================END==========================="
done
