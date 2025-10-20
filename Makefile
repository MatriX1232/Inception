# Alternative Makefile for the Inception project — same behavior, different structure

# --- Configurable values (new names) ---
COMPOSE_YAML := srcs/docker-compose.yml
WPCLI_FILE := srcs/requirements/wordpress/tools/wpcli.phar
KEY_STORE := vault
PERSIST_ROOT := /home/msolinsk/data_store
ENV_FILE := srcs/.env

# New host marker
HOST_MARKER := "# Inception Host Entry"

# --- Targets ---
.PHONY: start prepare install_engine ensure_compose fetch_wp secretize make_storage up down tidy deepclean reset purge_hosts add_host remove_host

start: prepare up
	@printf "=> All services requested: started (or were already running)\n"

prepare: install_engine ensure_compose fetch_wp secretize make_storage add_host
	@printf "=> System prepared\n"

# Install Docker if missing (different checks & steps)
install_engine:
	@printf "Checking for Docker engine...\n"
	@bash -c 'if ! hash docker 2>/dev/null; then \
		printf "Docker missing — adding repo and installing\n"; \
		sudo apt-get update -y && sudo apt-get install -y apt-transport-https ca-certificates gnupg lsb-release curl; \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo $$UBUNTU_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
		sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin; \
		sudo usermod -aG docker $${USER}; \
		printf "Docker installed. You may need to re-login.\n"; \
	else printf "Docker already installed\n"; fi'

# Ensure Docker Compose plugin exists (alternate check)
ensure_compose:
	@printf "Verifying Docker Compose plugin...\n"
	@bash -c 'if ! docker compose version >/dev/null 2>&1; then \
		printf "Compose plugin not available — installing package\n"; \
		sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin; \
		printf "Compose plugin installed\n"; \
	else printf "Compose plugin present\n"; fi'

# Fetch WP-CLI using wget (different tool) and create parent dirs
fetch_wp:
	@printf "Ensuring WP-CLI is present...\n"
	@bash -c 'if [ ! -f "$(WPCLI_FILE)" ]; then \
		printf "Downloading WP-CLI...\n"; \
		mkdir -p $$(dirname "$(WPCLI_FILE)"); \
		wget -q -O "$(WPCLI_FILE)" https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x "$(WPCLI_FILE)"; \
		printf "WP-CLI saved to %s\n" "$(WPCLI_FILE)"; \
	else printf "WP-CLI already present at %s\n" "$(WPCLI_FILE)"; fi'

# Create secrets directory and generate hex secrets if missing (different naming & method)
secretize:
	@printf "Creating secret tokens if absent...\n"
	@bash -c 'mkdir -p "$(KEY_STORE)"; \
	for f in db_pw root_db_pw wp_admin_pw; do \
		fn="$(KEY_STORE)/$${f}.txt"; \
		if [ ! -f "$$fn" ]; then \
			openssl rand -hex 16 > "$$fn" && chmod 600 "$$fn" && printf "Generated %s\n" "$$fn"; \
		else printf "Skipping existing %s\n" "$$fn"; fi; \
	done'

# Prepare persistent directories (different names)
make_storage:
	@printf "Making persistent storage under %s\n" "$(PERSIST_ROOT)"
	@mkdir -p "$(PERSIST_ROOT)/mariadb" "$(PERSIST_ROOT)/wordpress"
	@chmod 755 "$(PERSIST_ROOT)" || true

# Start stack using docker compose (explicit -f)
up:
	@printf "Bringing up containers (build + detach)...\n"
	@docker compose -f "$(COMPOSE_YAML)" up --build -d
	@docker compose -f "$(COMPOSE_YAML)" ps

down:
	@printf "Stopping stack...\n"
	@docker compose -f "$(COMPOSE_YAML)" down

tidy: down
	@printf "Tidying: stopped services\n"

deepclean: tidy
	@printf "Full cleanup: removing images, volumes, tools and secrets\n"
	@docker compose -f "$(COMPOSE_YAML)" down --rmi all -v || true
	@rm -f "$(WPCLI_FILE)" || true
	@rm -rf "$(KEY_STORE)" || true
	@rm -rf "$(PERSIST_ROOT)" || true
	@printf "Cleanup complete\n"

reset: deepclean add_host
	@printf "Rebuilding from scratch...\n"
	$(MAKE) prepare
	$(MAKE) up

# Purge: try to remove all docker artifacts safely (different commands)
purge:
	@printf "Attempting to purge Docker resources (requires sudo)...\n"
	@sudo systemctl stop docker || true
	@-sudo docker ps -aq | xargs -r sudo docker rm -f || true
	@-sudo docker images -aq | xargs -r sudo docker rmi -f || true
	@-sudo docker volume ls -q | xargs -r sudo docker volume rm || true
	@-sudo docker network ls -q | xargs -r sudo docker network rm || true
	@sudo systemctl start docker || true
	@printf "Purge finished\n"

# Hosts management (different marker and flow)
add_host:
	@echo "Configuring /etc/hosts file..."
	@if [ "$$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi; \
	VM_IP=$$(hostname -I | awk '{print $$1}'); \
	DOMAIN_NAME=$$(grep DOMAIN_NAME srcs/.env | cut -d '=' -f2); \
	COMMENT="# Inception Project Host"; \
	HOSTS_ENTRY="$$VM_IP $$DOMAIN_NAME $$COMMENT"; \
	if grep -q "$$DOMAIN_NAME" /etc/hosts; then \
		echo "Entry for '$$DOMAIN_NAME' already exists in /etc/hosts."; \
	else \
		echo "Adding entry to /etc/hosts. Sudo password may be required."; \
		echo "$$HOSTS_ENTRY" | $$SUDO tee -a /etc/hosts > /dev/null; \
		echo "Host entry added successfully."; \
	fi

remove_host:
	@echo "Removing Inception host entry from /etc/hosts..."
	@if [ "$$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi; \
	COMMENT="# Inception Project Host"; \
	if grep -q "$$COMMENT" /etc/hosts; then \
		echo "Found entry. Sudo password may be required to remove it."; \
		$$SUDO sed -i "/$$COMMENT/d" /etc/hosts; \
		echo "Host entry removed."; \
	else \
		echo "No Inception host entry found to remove."; \
	fi

# Convenience alias
clean: tidy

fclean: deepclean remove_host
	@printf "Performed full clean + host removal\n"