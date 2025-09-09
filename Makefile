all: up

up :
	@docker-compose -f ./srcs/docker-compose.yml up -d

up-build :
	@docker-compose -f ./srcs/docker-compose.yml up --build -d

down : 
	@docker-compose -f ./srcs/docker-compose.yml down

stop : 
	@docker-compose -f ./srcs/docker-compose.yml stop

start : 
	@docker-compose -f ./srcs/docker-compose.yml start

clean :
	docker rmi -f $(docker images -aq)

status : 
	@docker ps