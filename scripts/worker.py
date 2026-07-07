import socket
import subprocess
import sys
import re
from typing import Tuple


MASTER_IP = '34.30.161.127'
PORT = 5000



def grab_coordinates(s: str) -> Tuple[int, int, int]:
  result = re.search(r"SUCCESS,([0-9\-]+),([0-9\-]+),(\d+)", s)
  if result:
    return (int(result.group(1)),int(result.group(2)),int(result.group(3)))
  else:
    return (-1,-1,-1)



def main():
    print("[+] Connecting to GCP Master at {MASTER_IP}:{PORT}...")
    try:
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client.connect((MASTER_IP, PORT))
        print("[+] Connected successfully! Awaiting seeds...")
    except Exception as e:
        print(f"[-] Connection failed: {e}")
        return

    buffer = ""
    while True:
        data = client.recv(1024).decode()
        if not data:
            print("[-] Lost connection to Master.")
            break
        buffer += data

        if '\n' in buffer:
            command, buffer = buffer.split('\n', 1)
            if command.startswith("STOP"):
                print("[*] Stop signal received from master.")
                break
            if command.startswith("SEED:"):
                seed = command.split(":")[1]

                # Execute the compiled binary on Colab
                result = subprocess.run(['./main', seed], capture_output=True, text=True)

                if "SUCCESS" in result.stdout:
                    (x, z, global_min) = grab_coordinates(result.stdout.strip())
                    client.sendall(f"FOUND {x},{z},{global_min}\n".encode())
                    print(f"[!] Target found at seed: {seed}")
                    break
                else:
                    client.sendall(b"NOT_FOUND\n")

if __name__ == "__main__":
    main()
