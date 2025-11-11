# =============================================================================
# Inception Project Orchestration
# =============================================================================

SHELL := /bin/sh

COMPOSE_CFG   := srcs/docker-compose.yml
WP_TOOL       := srcs/requirements/wordpress/tools/wp-cli.phar
SECRET_VAULT  := secrets
DATA_ROOT     := /home/msolinsk/data
MARIA_STORE   := $(DATA_ROOT)/mariadb
WP_STORE      := $(DATA_ROOT)/wordpress

ENV_FILE      := srcs/.env
HOST_DOMAIN   := $(shell grep '^DOMAIN_NAME=' $(ENV_FILE) | cut -d= -f2)
POUND         := #
HOST_MARK     := $(POUND) Inception Project Host
CURRENT_IP    := $(shell hostname -I | awk '{print $$1}')
SUDO_BIN      := $(shell if [ `id -u` -ne 0 ]; then echo sudo; fi)

.PHONY: all setup up down clean fclean re purge \
        install-docker install-docker-compose download-wp-cli \
        secrets create-volumes hosts clean-hosts

define say
	@printf '%s\n' $(1)
endef

# -----------------------------------------------------------------------------
# Composite targets
# -----------------------------------------------------------------------------
all: setup up

setup: install-docker install-docker-compose download-wp-cli secrets create-volumes hosts
	$(call say,"==========================================")
	$(call say,"Setup complete! Project is ready to launch.")
	$(call say,"==========================================")

up:
	$(call say,"Building and starting all services...")
	@docker compose -f $(COMPOSE_CFG) up --build -d
	$(call say,"---------------------------------------------------------")
	$(call say,"SUCCESS: All services are up and running.")
	$(call say,"---------------------------------------------------------")
	@docker compose -f $(COMPOSE_CFG) ps

down:
	$(call say,"Stopping and removing containers...")
	@docker compose -f $(COMPOSE_CFG) down
	$(call say,"Services have been stopped.")

clean: down

fclean: clean-hosts
	$(call say,"Performing a full cleanup...")
	@docker compose -f $(COMPOSE_CFG) down --rmi all -v
	$(call say,"Removing downloaded tools...")
	@rm -f $(WP_TOOL)
	$(call say,"Removing secrets...")
	@rm -rf $(SECRET_VAULT)
	$(call say,"Removing volume directories...")
	@rm -rf $(DATA_ROOT)
	$(call say,"Full cleanup complete.")

re: fclean all

purge: fclean clean-hosts
	@echo "Purging Docker system..."
	@-sudo docker stop $$(sudo docker ps -qa) 2>/dev/null || true
	@-sudo docker rm $$(sudo docker ps -qa) 2>/dev/null || true
	@-sudo docker rmi -f $$(sudo docker images -qa) 2>/dev/null || true
	@-sudo docker volume rm $$(sudo docker volume ls -q) 2>/dev/null || true
	@-sudo docker network rm $$(sudo docker network ls -q) 2>/dev/null || true
	@-sudo docker builder prune -a -f 2>/dev/null || true
	@-sudo docker network prune -f 2>/dev/null || true
	@-sudo systemctl restart docker
	@-sudo rm -rf $(SECRETS_DIR)
	@echo "Docker system has been purged."

# -----------------------------------------------------------------------------
# Prerequisite helpers
# -----------------------------------------------------------------------------
install-docker:
	$(call say,"Checking Docker installation...")
	@if command -v docker >/dev/null 2>&1; then \
		printf 'Docker is already installed.\n'; \
	else \
		printf 'Docker not found. Installing Docker...\n'; \
		sudo apt-get update; \
		sudo apt-get install -y ca-certificates curl gnupg; \
		sudo install -m 0755 -d /etc/apt/keyrings; \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
		sudo chmod a+r /etc/apt/keyrings/docker.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo "$$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
		sudo apt-get update; \
		sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; \
		sudo usermod -aG docker $$USER; \
		printf 'Docker installed successfully.\n'; \
		printf "NOTE: You may need to log out and log back in, or run 'newgrp docker' to apply group permissions.\n"; \
	fi

install-docker-compose:
	$(call say,"Checking Docker Compose installation...")
	@if docker compose version >/dev/null 2>&1; then \
		printf 'Docker Compose is already installed.\n'; \
	else \
		printf 'Docker Compose plugin not found. Installing...\n'; \
		sudo apt-get update; \
		sudo apt-get install -y docker-compose-plugin; \
		printf 'Docker Compose installed successfully.\n'; \
	fi

download-wp-cli:
	$(call say,"Checking WP-CLI...")
	@if [ -f "$(WP_TOOL)" ]; then \
		printf 'WP-CLI is already present.\n'; \
	else \
		printf 'WP-CLI not found. Downloading...\n'; \
		mkdir -p $$(dirname $(WP_TOOL)); \
		curl -o $(WP_TOOL) https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
		printf 'WP-CLI downloaded successfully.\n'; \
	fi

# -----------------------------------------------------------------------------
# Project resources
# -----------------------------------------------------------------------------
secrets:
	$(call say,"Generating secrets with random passwords...")
	@mkdir -p $(SECRET_VAULT)
	@for token in db_password db_root_password wp_admin_password; do \
		target="$(SECRET_VAULT)/$$token.txt"; \
		if [ -f "$$target" ]; then \
			printf '%s already exists, skipping...\n' "$$token.txt"; \
		else \
			openssl rand -base64 18 | tr -d '\n' > "$$target"; \
			printf 'Generated %s\n' "$$token.txt"; \
		fi; \
	done
	@chmod 600 $(SECRET_VAULT)/*.txt
	$(call say,"Secrets generated successfully.")

create-volumes:
	$(call say,"Creating volume directories...")
	@mkdir -p $(MARIA_STORE) $(WP_STORE)
	$(call say,"Volume directories created at $(DATA_ROOT)")

# -----------------------------------------------------------------------------
# Host file maintenance
# -----------------------------------------------------------------------------
hosts:
	$(call say,"Configuring /etc/hosts file...")
	@entry="$(CURRENT_IP) $(HOST_DOMAIN) $(HOST_MARK)"; \
	if grep -q "$$entry" /etc/hosts; then \
		printf "Entry for '%s' already exists in /etc/hosts.\n" "$(HOST_DOMAIN)"; \
	else \
		printf "Adding entry to /etc/hosts. Sudo password may be required.\n"; \
		echo "$$entry" | $(SUDO_BIN) tee -a /etc/hosts >/dev/null; \
		printf 'Host entry added successfully.\n'; \
	fi

clean-hosts:
	$(call say,"Removing Inception host entry from /etc/hosts...")
	@if grep -q "$(HOST_MARK)" /etc/hosts; then \
		printf 'Found entry. Sudo password may be required to remove it.\n'; \
		$(SUDO_BIN) sed -i "/$(HOST_MARK)/d" /etc/hosts; \
		printf 'Host entry removed.\n'; \
	else \
		printf 'No Inception host entry found to remove.\n'; \
	fi