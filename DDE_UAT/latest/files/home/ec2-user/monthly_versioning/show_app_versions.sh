#!/bin/bash


#kubectl apply -f deployment_artifacts/

#sleep 10

#exit 
cd ..

kubectl get pods > $$kubedata

llist="client-depl dde-depl loader-depl worker-depl"

touch $$temp
rm $$temp

for pod in $llist
do
   NAM=$(cat $$kubedata | grep $pod | awk '{print $1}')

   PUB_VERSION=$(cat deployment_artifacts/${pod}.yaml | grep -A1 -i annotations | tail -1 | awk '{print $2}' | sed "s/\"//g")

   RUN_VERSION=$(kubectl get pod $NAM -o jsonpath="{.metadata.annotations.version}")

   if [ $PUB_VERSION"x" == "x" ];then
     PUB_VERSION="Not_Avaialble"
   fi

   if [ $RUN_VERSION"x" == "x" ];then
     RUN_VERSION="NaN"
   fi

   #echo $RUN_VERSION | awk -v N1=$pod -v N2=$NAM -v N3=$PUB_VERSION '{printf "%-15s %-30s %-25s %-15s\n",N1,N2,N3,$0}' >> $$temp
   echo $RUN_VERSION | awk -v N1=$pod -v N2=$NAM -v N3=$PUB_VERSION -v timestamp=$(date '+%Y-%m-%d') '{printf "%-20s %-15s %-30s %-25s %-15s\n", timestamp, N1, N2, N3, $0}' >> $$temp
done

#echo "Pod Pod_Full_Name Published_version Running_version" | awk '{printf "%-15s %-30s %-25s %-15s\n",$1,$2,$3,$4}'
cat $$temp
echo

rm $$kubedata $$temp

