#!/bin/bash
set -euxo pipefail

# TEST 1: Building and running the application

# LMP 3.0+ goals are listed here: https://github.com/OpenLiberty/ci.maven#goals

## Rebuild the application
#       package                   - Take the compiled code and package it in its distributable format.
#       liberty:create            - Create a Liberty server.
#       liberty:install-feature   - Install a feature packaged as a Subsystem Archive (esa) to the Liberty runtime.
#       liberty:deploy            - Copy applications to the Liberty server's dropins or apps directory. 
mvn -q clean package liberty:create liberty:install-feature liberty:deploy

mvn package

## Run the tests
# These commands are separated because if one of the commands fail, the test script will fail and exit. 
# e.g if liberty:start fails, then there is no need to run the failsafe commands. 
#       liberty:start             - Start a Liberty server in the background.
#       failsafe:integration-test - Runs the integration tests of an application.
#       liberty:stop              - Stop a Liberty server.
#       failsafe:verify           - Verifies that the integration tests of an application passed.
mvn liberty:start
mvn failsafe:integration-test liberty:stop
mvn failsafe:verify

# TEST 2:  Running the application in Kubernetes
docker build -t cart-app:1.0-SNAPSHOT .

sleep 120

kubectl apply -f kubernetes.yaml

sleep 120

kubectl get pods

echo `minikube ip`

postStatus="$(curl -X POST "http://localhost:31000/guide-sessions/cart/eggs&2.29" --cookie "c.txt" --cookie-jar "c.txt")"
getStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://`minikube ip`:31000/guide-sessions/cart" --cookie "c.txt" --cookie-jar "c.txt")"
openApiStatus="$(curl --write-out "%{http_code}\n" --silent --output /dev/null "http://`minikube ip`:31000/openapi/ui/")"
runningPod="$(curl --silent "http://`minikube ip`:31000/guide-sessions/cart" --cookie "c.txt" --cookie-jar "c.txt" | sed 's/^.*\(cart-.*\)/\1/' | sed 's/".*//')"

echo post status 
echo "$postStatus"
echo get status
echo "$getStatus"
echo running pod
echo "$runningPod"

kubectl exec $runningPod -- cat /logs/messages.log | grep product
kubectl exec $runningPod -- cat /logs/messages.log | grep java

if [ "$postStatus" == 'eggs added to your cart and costs $2.29' ] && [ "$getStatus" == "200" ] && [ "$openApiStatus" == "200" ]
then
    echo POST/GET OK
else
    echo post status:
    echo "$postStatus"
    echo get status:
    echo "$getStatus"
    exit 1
fi
