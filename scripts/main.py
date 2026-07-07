import socket
import threading

# Configuration
HOST = '0.0.0.0'  # Listen on all available network interfaces
PORT = 5000

# The block of seeds you want to search through (Modify this range as needed)
# For example: checking seeds from 0 to 10000
seed_queue = list(range(0, 10000))
queue_lock = threading.Lock()
found_seed = None

def handle_worker(conn, addr):
    global found_seed
    print(f"[+] Worker connected from {addr}")

    try:
        while True:
            # Check if another worker already found the seed
            if found_seed is not None:
                conn.sendall(b"STOP\n")
                break

            # Get the next seed from the queue safely
            with queue_lock:
                if not seed_queue:
                    print("[-] All seeds evaluated. Queue is empty.")
                    conn.sendall(b"STOP\n")
                    break
                current_seed = seed_queue.pop(0)

            # Send the seed to the worker
            conn.sendall(f"SEED:{current_seed}\n".encode())

            # Wait for the worker's response
            response = conn.recv(1024).decode().strip()

            if response.startswith("FOUND"):
                print(f"[!!!] SUCCESS: Worker {addr} found the target! {response}")
                found_seed = current_seed
                break
            elif response == "NOT_FOUND":
                # Move on to the next seed
                continue
    except Exception as e:
        print(f"[-] Worker {addr} disconnected abruptly: {e}")
    finally:
        conn.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen()
    print(f"[+] Master Dispatcher active. Listening on port {PORT}...")

    while found_seed is None:
        conn, addr = server.accept()
        # Spin up a thread to talk to this specific worker while keeping the main loop open
        client_thread = threading.Thread(target=handle_worker, args=(conn, addr))
        client_thread.start()

if __name__ == "__main__":
    main()
