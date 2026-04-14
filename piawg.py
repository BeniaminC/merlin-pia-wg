import requests
import json
import subprocess

class piawg:
    def __init__(self):
        self.server_list = {}
        self.get_server_list()
        self.region = None
        self.token = None
        self.publickey = None
        self.privatekey = None
        self.connection = None

    def get_server_list(self):
        r = requests.get('https://serverlist.piaservers.net/vpninfo/servers/v4')
        data = json.loads(r.text.splitlines()[0])
        for server in data['regions']:
            self.server_list[server['name']] = server

    def set_region(self, region_name):
        self.region = region_name

    def get_token(self, username, password):
        # Mapped perfectly from get_token.sh
        # This is a public URL, so normal DNS and SSL work flawlessly.
        url = 'https://www.privateinternetaccess.com/api/client/v2/token'

        try:
            r = requests.post(url, data={"username": username, "password": password})
            if r.status_code == 200:
                data = r.json()
                if 'token' in data:
                    self.token = data['token']
                    return True
            else:
                print(f"Error fetching token: HTTP {r.status_code}")
                return False
        except Exception as e:
            print(f"Token generation failed: {e}")
            return False

    def generate_keys(self):
        self.privatekey = subprocess.run(['wg', 'genkey'], stdout=subprocess.PIPE, encoding="utf-8", check=True).stdout.strip()
        self.publickey = subprocess.run(['wg', 'pubkey'], input=self.privatekey, stdout=subprocess.PIPE, encoding="utf-8", check=True).stdout.strip()

    def addkey(self):
        cn = self.server_list[self.region]['servers']['wg'][0]['cn']
        ip = self.server_list[self.region]['servers']['wg'][0]['ip']

        # Mapped perfectly from connect_to_wireguard_with_token.sh
        # curl natively handles the complex IP routing and SNI spoofing.
        cmd = [
            "curl", "-s", "-G",
            "--connect-to", f"{cn}::{ip}:",
            "--cacert", "ca.rsa.4096.crt",
            "--data-urlencode", f"pt={self.token}",
            "--data-urlencode", f"pubkey={self.publickey}",
            f"https://{cn}:1337/addKey"
        ]

        try:
            # Execute the curl command
            result = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True)
            response_json = json.loads(result.stdout)

            if response_json.get('status') == 'OK':
                self.connection = response_json
                return True, result.stdout
            else:
                return False, result.stdout
        except Exception as e:
            return False, str(e)