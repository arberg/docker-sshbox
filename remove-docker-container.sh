. env
# down command removes container AND its network
# --rmi further deletes: images built by the project
# --volumes further deletes: named volumes
sudo docker-compose down --rmi local
