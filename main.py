from docker import install_docker
from n8n import start_n8n_container
from utils import env_vars, local_timezone
from utils import run_command


# INSTALL DOCKER (if needed) 
install_docker()
print("""
There is no undo functionality. If you enter a question wrong and submit it you must run the script again with the original command.

Reminder: You will have keys in a .env file on your system after this proccess. You are responsible to secure it.
""")


is_custom_image = False
list_of_packages = []


# ------------------------------------------------------------------------
# -------------------      GENERIC CONFIGURATION      --------------------
# ------------------------------------------------------------------------

# Sets var for detailed setup type
detailed_setup = False

# Sets URL
domain = "localhost"
env_vars['N8N_EDITOR_BASE_URL'] = f'http://{domain}:5678'
env_vars['WEBHOOK_URL'] = f'http://{domain}:5678'


# Sets Timezone
env_vars["GENERIC_TIMEZONE"] = str(local_timezone) or "America/New_York"


print("\nstarting n8n...")
start_n8n_container(env_vars, is_custom_image, list_of_packages)
print("n8n started")


print("""
Thank you for using my tool!
Please give me feedback if you have any!
      
liam@teraprise.io
""")

# TODO: add cleanup scripts here
print("deleting temp folder...")
run_command("rm -rf n8n-auto-install")
