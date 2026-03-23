kubectl get secret tls -o jsonpath="{.data['tls\.crt']}" | base64 --decode | openssl x509 -noout -dates
