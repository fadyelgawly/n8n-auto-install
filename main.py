from docker import install_docker
from n8n import start_n8n_container
from utils import env_vars, local_timezone
from utils import run_command

# INSTALL DOCKER (if needed)
install_docker()
print("""
Reminder: You will have keys in a .env file on your system after this proccess. You are responsible to secure it.
""")

# --- GENERIC CONFIGURATION ---
env_vars['N8N_EDITOR_BASE_URL'] = 'http://localhost:5678'
env_vars['WEBHOOK_URL'] = 'http://localhost:5678'
env_vars["GENERIC_TIMEZONE"] = str(local_timezone) or "America/New_York"
env_vars['N8N_SECURE_COOKIE'] = false

# --- Start n8n ---
print("\nstarting n8n...")
start_n8n_container(env_vars, is_custom_image=False, list_of_packages=[])
print("n8n started")

print("""
Thank you for using my tool!
""")

# --- Cleanup ---
print("deleting temp folder...")
run_command("rm -rf n8n-auto-install")
