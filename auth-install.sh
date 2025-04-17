#!/bin/bash

# This script sets up Basic HTTP Authentication for PMSS when running under Nginx.
# It assumes that user registration and password management are handled externally.
# The script:
#   1. Ensures strict shell settings for security.
#   2. Checks for the presence of the htpasswd tool.
#   3. Validates that the Nginx document root exists.
#   4. Verifies that the .htpasswd file exists, or creates it with a header and secure permissions.
#   5. Displays an Nginx configuration snippet that uses secure settings.
#   6. Attempts to reload Nginx.
#
# Usage:
#   chmod +x auth-install.sh
#   ./auth-install.sh
#
# Customize the following variables as needed:

set -euo pipefail
IFS=$'\n\t'

NGINX_DOC_ROOT="${NGINX_DOC_ROOT:-/var/www}"  # Must be an existing directory.
HTPASSWD_FILE="${NGINX_HTPASSWD_FILE:-/etc/seedbox/config/.htpasswd}"  # Externally managed credentials.

echo "Setting up Basic HTTP Authentication for PMSS (Nginx mode)..."

# Validate that the document root exists and is a directory.
if [ ! -d "${NGINX_DOC_ROOT}" ]; then
    echo "Error: Nginx document root '${NGINX_DOC_ROOT}' does not exist." >&2
    exit 1
fi

# Check that the htpasswd tool is available.
if ! command -v htpasswd &>/dev/null; then
    echo "Error: 'htpasswd' command not found. Please install apache2-utils (Debian/Ubuntu) or httpd-tools (RHEL/CentOS) first." >&2
    exit 1
fi

# Ensure the parent directory for the .htpasswd file exists.
HTPASSWD_DIR=$(dirname "${HTPASSWD_FILE}")
if [ ! -d "${HTPASSWD_DIR}" ]; then
    echo "Creating directory for .htpasswd file: ${HTPASSWD_DIR}"
    sudo mkdir -p "${HTPASSWD_DIR}"
fi

# Check if the .htpasswd file exists. If not, create it with a header comment and secure permissions.
if [ ! -f "${HTPASSWD_FILE}" ]; then
    echo "WARNING: ${HTPASSWD_FILE} does not exist."
    echo "Creating a placeholder .htpasswd file. Please update it manually with valid user credentials."
    {
      echo "# This file is managed externally. Add your user entries in the format:"
      echo "# username:hashed_password"
    } | sudo tee "${HTPASSWD_FILE}" >/dev/null
    # Set restrictive permissions
    sudo chmod 640 "${HTPASSWD_FILE}"
else
    echo ".htpasswd file found at: ${HTPASSWD_FILE}"
fi

echo ""
cat <<'EOF'

------------------------------------------------------------
Add the following directives to your Nginx configuration,
inside the server or location block that serves PMSS (e.g. in /etc/nginx/sites-available/your_site):

    auth_basic "Restricted Area - Authorized Personnel Only";
    auth_basic_user_file <PATH_TO_YOUR_HTPASSWD_FILE>;

Replace <PATH_TO_YOUR_HTPASSWD_FILE> with the following path:
EOF

echo "    ${HTPASSWD_FILE}"
cat <<'EOF'

Example:

server {
    listen 80;
    server_name your_domain_or_IP;
    root <YOUR_NGINX_DOC_ROOT>;
    index index.php index.html;

    location / {
        auth_basic "Restricted Area - Authorized Personnel Only";
        auth_basic_user_file <PATH_TO_YOUR_HTPASSWD_FILE>;
        try_files $uri $uri/ /index.php;
    }
}
------------------------------------------------------------
EOF

echo ""
echo "Your Nginx document root is: ${NGINX_DOC_ROOT}"
echo "Your .htpasswd file is set to   : ${HTPASSWD_FILE}"
echo ""

# Optionally, attempt to reload Nginx.
echo "Attempting to reload Nginx..."
if sudo systemctl reload nginx; then
    echo "Nginx reloaded successfully."
else
    echo "Failed to reload Nginx. Please check your Nginx configuration and reload manually." >&2
fi
