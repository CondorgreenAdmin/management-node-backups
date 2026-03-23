#!/bin/bash
#AUTHOR: 	Julian Schubel
#CONTACT: 	julian.schubel@condorgreen.com
#UPDATED:	09/06/2021
#PRECONDITION:	Must have signed on with aws cli using `aws sso login`

LAYER_NAME=$1
declare -a PACKAGES=()
ZIP_ARTIFACT=${LAYER_NAME}.zip
LAYER_DIRECTORY="python/"
REQUIRED_ARGUMENTS=1
RUNTIME="python3.8"

usage()
{
    echo "Usage: $0 LAYER_NAME [-m PACKAGE1 -m PACKAGE2 ...]" 1>&2;
    exit 1;
}

echo "CREATING LAYER: ${LAYER_NAME}"
#shift

echo "MODULES: "
if test $# -lt 2; then
	usage 
	exit 1
fi

#Need to shift arguments left as getopts starts from $1
shift

#Read arguments after the -m option flag and append to the PACKAGES array
while getopts ":m:" opt; do 
    case "${opt}" in
        m)
            echo -e "\t${OPTARG}"
            PACKAGES+=("$OPTARG")
            ;;
	    :)
	        echo -e "Error: ${OPTARG} requires an argument"
            exit 1
	        ;;
        *)
            usage
	        exit 1
    esac
done

#Install libraries / modules
mkdir -p ${LAYER_DIRECTORY} 

python3 -m venv venv

source venv/bin/activate

for package in "${PACKAGES[@]}"; do
    python3 -m pip install \
        --platform manylinux2010_x86_64 \
        --python 3.8 \
        -t ${LAYER_DIRECTORY} \
        --only-binary=:all: \
        "${package}"
    #continue
done

deactivate

#Create the zip file for upload to AWS
zip -r ./${ZIP_ARTIFACT} ${LAYER_DIRECTORY}

#request list of compatible runtimes from user
echo "Input a comma delimited list of compatible runtimes for the layer"
IFS= read -r string;
RUNTIME=$string;

#Publish to AWS
echo "Publishing layer to AWS..."
aws --profile prd-dde-integration --region af-south-1 lambda publish-layer-version --layer-name ${LAYER_NAME} --zip-file fileb://${ZIP_ARTIFACT} --compatible-runtimes ${RUNTIME}

#Cleaning up
rm -rdf "${LAYER_DIRECTORY}"
