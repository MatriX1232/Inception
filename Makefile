# Inception project Makefile (refactored for readability and style)
# Provides the same targets and behavior as the original Makefile.old

# --- Paths & configuration ---
DC_FILE        := srcs/docker-compose.yml
WP_PHAR        := srcs/requirements/wordpress/tools/wp-cli.phar
SECRETS_DIR    := secrets
DATA_ROOT      := /home/msolinsk/data

# --- Phony targets ---
.PHONY: all default setup install-docker install-docker-compose download-wp-cli \
        create-volumes up down clean fclean re purge hosts clean-hosts secrets \
        _check_docker _install_docker _check_compose _install_compose

# default entry -> same as original: run full setup then launch
all: setup up

# keep make without target friendly
default: all

# --- High-level orchestration ---
setup: install-docker install-docker-compose download-wp-cli secrets create-volumes hosts
	@printf "\n=== Setup finished: environment prepared ===\n\n"

# --- Install helpers (refactored into smaller private targets) ---
install-docker: _check_docker

_check_docker:
	@printf ">> Checking for Docker executable...\n"
	@if ! command -v docker >/dev/null 2>&1; then \
		printf "Docker missing -> invoking installer target...\n"; \
		$(MAKE) _install_docker; \
	else \
		printf "Docker already installed.\n"; \
	fi

_install_docker:
	@printf ">> Installing Docker (apt)...\n"
	@sudo apt-get update; \
	sudo apt-get install -y ca-certificates curl gnupg; \
	sudo install -m 0755 -d /etc/apt/keyrings; \
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
	sudo chmod a+r /etc/apt/keyrings/docker.gpg; \
	echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo "$$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
	sudo apt-get update; \
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; \
	sudo usermod -aG docker $$USER || true; \
	printf "Docker install complete. You may need to re-login or run 'newgrp docker'.\n"

install-docker-compose: _check_compose

_check_compose:
	@printf ">> Verifying Docker Compose plugin...\n"
	@if ! docker compose version >/dev/null 2>&1; then \
		printf "Docker Compose plugin not present -> invoking installer target...\n"; \
		$(MAKE) _install_compose; \
	else \
		printf "Docker Compose plugin is installed.\n"; \
	fi

_install_compose:
	@printf ">> Installing Docker Compose plugin (apt)...\n"
	@sudo apt-get update; \
	sudo apt-get install -y docker-compose-plugin; \
	printf "Docker Compose plugin installed.\n"

# --- Tools download ---
download-wp-cli:
	@printf ">> Ensuring WP-CLI is available at '$(WP_PHAR)'\n"
	@mkdir -p $$(dirname "$(WP_PHAR)")
	@if [ ! -f "$(WP_PHAR)" ]; then \
		printf "Downloading WP-CLI...\n"; \
		curl -sSfL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o "$(WP_PHAR)"; \
		chmod +x "$(WP_PHAR)" || true; \
		printf "WP-CLI downloaded.\n"; \
	else \
		printf "WP-CLI already present.\n"; \
	fi

# --- Secrets & volumes (consolidated secret creation) ---
secrets:
	@printf ">> Creating secrets in '$(SECRETS_DIR)'\n"
	@mkdir -p "$(SECRETS_DIR)"
	@for name in db_password db_root_password wp_admin_password; do \
		file="$(SECRETS_DIR)/$$name.txt"; \
		if [ ! -f "$$file" ]; then \
			openssl rand -base64 18 | tr -d '\n' > "$$file"; \
			printf "Created $$file\n"; \
		else \
			printf "$$file exists, skipping\n"; \
		fi; \
	done
	@chmod 600 "$(SECRETS_DIR)"/*.txt 2>/dev/null || true
	@printf "Secrets prepared.\n"

create-volumes:
	@printf ">> Creating persistent volume directories under $(DATA_ROOT)\n"
	@mkdir -p "$(DATA_ROOT)/mariadb" "$(DATA_ROOT)/wordpress"
	@printf "Volume directories ready: $(DATA_ROOT)/{mariadb,wordpress}\n"

# --- Docker lifecycle ---
up:
	@printf ">> Building and launching containers (docker compose)...\n"
	@docker compose -f "$(DC_FILE)" up --build -d
	@printf "-------------------------------------------------\n"
	@printf "Containers are up.\n"
	@docker compose -f "$(DC_FILE)" ps

down:
	@printf ">> Bringing containers down...\n"
	@docker compose -f "$(DC_FILE)" down
	@printf "Services stopped.\n"

clean: down

fclean: clean-hosts
	@printf ">> Full cleanup: removing images, volumes, tools and local data\n"
	@docker compose -f "$(DC_FILE)" down --rmi all -v
	@rm -f "$(WP_PHAR)" || true
	@rm -rf "$(SECRETS_DIR)" || true
	@rm -rf "$(DATA_ROOT)" || true
	@printf "Full cleanup completed.\n"

re: fclean all

purge: fclean clean-hosts
	@printf ">> Purging Docker system (containers/images/volumes/networks/build cache)\n"
	@-sudo docker stop $$(sudo docker ps -qa) 2>/dev/null || true
	@-sudo docker rm $$(sudo docker ps -qa) 2>/dev/null || true
	@-sudo docker rmi -f $$(sudo docker images -qa) 2>/dev/null || true
	@-sudo docker volume rm $$(sudo docker volume ls -q) 2>/dev/null || true
	@-sudo docker network rm $$(sudo docker network ls -q) 2>/dev/null || true
	@-sudo docker builder prune -a -f 2>/dev/null || true
	@-sudo docker network prune -f 2>/dev/null || true
	@-sudo systemctl restart docker 2>/dev/null || true
	@-sudo rm -rf "$(SECRETS_DIR)" 2>/dev/null || true
	@printf "Docker system purge finished.\n"

# --- Hosts file helpers ---
hosts:
	@printf ">> Ensuring /etc/hosts contains the Inception domain entry\n"
	@SUDO=""; if [ "$$(id -u)" -ne 0 ]; then SUDO="sudo"; fi; \
	VM_IP=$$(hostname -I 2>/dev/null | awk '{print $$1}'); \
	DOMAIN_NAME=$$(grep -E '^DOMAIN_NAME=' srcs/.env 2>/dev/null | cut -d'=' -f2); \
	COMMENT="# Inception Project Host"; \
	if [ -z "$$VM_IP" ]; then \
		printf "Could not determine VM IP (hostname -I failed). Skipping hosts entry.\n"; \
	elif [ -z "$$DOMAIN_NAME" ]; then \
		printf "DOMAIN_NAME not found in srcs/.env. Skipping hosts entry.\n"; \
	elif grep -qF "$$DOMAIN_NAME" /etc/hosts 2>/dev/null; then \
		printf "Hosts entry for $$DOMAIN_NAME already present.\n"; \
	else \
		printf "$$VM_IP $$DOMAIN_NAME $$COMMENT\n" | $$SUDO tee -a /etc/hosts > /dev/null; \
		printf "Added hosts entry for $$DOMAIN_NAME -> $$VM_IP\n"; \
	fi

clean-hosts:
	@printf ">> Removing Inception hosts entry (if present)\n"
	@SUDO=""; if [ "$$(id -u)" -ne 0 ]; then SUDO="sudo"; fi; \
	COMMENT="# Inception Project Host"; \
	if grep -qF "$$COMMENT" /etc/hosts 2>/dev/null; then \
		$$SUDO sed -i.bak "/$$COMMENT/d" /etc/hosts && printf "Removed Inception hosts entry (backup /etc/hosts.bak created).\n"; \