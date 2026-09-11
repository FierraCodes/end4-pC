#!/usr/bin/env python3
import os
import pty
import re
import select
import shutil
import signal
import subprocess
import sys
import time

ANSI_ESCAPE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def clean_text(text: str) -> str:
    cleaned = ANSI_ESCAPE.sub('', text)
    return cleaned.replace('\r', '')

def has_cmd(cmd: str) -> bool:
    return shutil.which(cmd) is not None

USE_KDIALOG = has_cmd('kdialog')
USE_ZENITY = has_cmd('zenity')

def dialog_yesno(title: str, text: str) -> bool:
    if USE_KDIALOG:
        res = subprocess.run(['kdialog', '--title', title, '--yesno', text])
        return res.returncode == 0
    elif USE_ZENITY:
        res = subprocess.run(['zenity', '--question', '--title', title, '--text', text])
        return res.returncode == 0
    return False

def dialog_input(title: str, text: str, default: str = "") -> tuple[bool, str]:
    if USE_KDIALOG:
        cmd = ['kdialog', '--title', title, '--inputbox', text]
        if default:
            cmd.append(default)
        res = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    elif USE_ZENITY:
        cmd = ['zenity', '--entry', '--title', title, '--text', text]
        if default:
            cmd.extend(['--entry-text', default])
        res = subprocess.run(cmd, stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    return False, ""

def dialog_password(title: str, text: str) -> tuple[bool, str]:
    if USE_KDIALOG:
        res = subprocess.run(['kdialog', '--title', title, '--password', text],
                             stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    elif USE_ZENITY:
        res = subprocess.run(['zenity', '--password', '--title', title, '--text', text],
                             stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            return True, res.stdout.rstrip('\r\n')
        return False, ""
    return False, ""

def dialog_error(title: str, text: str):
    if USE_KDIALOG:
        subprocess.run(['kdialog', '--title', title, '--error', text])
    elif USE_ZENITY:
        subprocess.run(['zenity', '--error', '--title', title, '--text', text])

def main():
    if len(sys.argv) < 2:
        print("Usage: connect_vpn_gui.py <uuid-or-name> [friendly-name]", file=sys.stderr)
        sys.exit(1)

    target = sys.argv[1]
    vpn_name = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else target
    window_title = f"VPN Authentication - {vpn_name}"

    if not USE_KDIALOG and not USE_ZENITY:
        print("Error: Neither kdialog nor zenity found.", file=sys.stderr)
        sys.exit(1)

    master, slave = pty.openpty()
    pid = os.fork()

    if pid == 0:
        # Child process
        os.close(master)
        os.dup2(slave, 0)
        os.dup2(slave, 1)
        os.dup2(slave, 2)
        os.close(slave)
        # Force C locale for predictable prompt matching
        env = os.environ.copy()
        env['LANG'] = 'C'
        env['LC_ALL'] = 'C'
        cmd = ['nmcli', 'connection', 'up', 'uuid', target, '--ask']
        try:
            os.execvpe('nmcli', cmd, env)
        except Exception as e:
            print(f"Failed to exec nmcli: {e}", file=sys.stderr)
            sys.exit(127)

    os.close(slave)

    def kill_child():
        try:
            os.kill(pid, signal.SIGTERM)
            time.sleep(0.2)
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, OSError):
            pass

    raw_output = b""
    accumulated_text = ""
    prompt_count = 0
    max_prompts = 20
    auth_failed = False

    try:
        while True:
            # Check if child process has exited
            child_pid, status = os.waitpid(pid, os.WNOHANG)
            if child_pid != 0:
                # Process exited
                exit_code = os.waitstatus_to_exitcode(status)
                # Drain remaining output
                while True:
                    r, _, _ = select.select([master], [], [], 0.1)
                    if not r:
                        break
                    try:
                        chunk = os.read(master, 1024)
                        if not chunk:
                            break
                        raw_output += chunk
                    except OSError:
                        break
                output_str = clean_text(raw_output.decode('utf-8', errors='replace'))
                sys.stdout.write(output_str)
                sys.stdout.flush()
                sys.exit(exit_code)

            r, _, _ = select.select([master], [], [], 0.3)
            if not r:
                continue

            try:
                chunk = os.read(master, 1024)
            except OSError:
                # EIO typically means slave was closed
                break

            if not chunk:
                break

            raw_output += chunk
            chunk_str = clean_text(chunk.decode('utf-8', errors='replace'))
            accumulated_text += chunk_str

            if "logincheck" in chunk_str or "Login failed" in chunk_str or "Authentication failed" in chunk_str:
                auth_failed = True

            # Check for prompts in accumulated_text
            # 1. SSL Certificate verification prompt
            cert_match = re.search(r"Enter 'yes' to accept, 'no' to abort; anything else to view:\s*$", accumulated_text)
            if not cert_match:
                cert_match = re.search(r"Certificate.*failed verification.*?Enter 'yes' to accept.*?:\s*$", accumulated_text, re.DOTALL)

            if cert_match:
                prompt_count += 1
                cert_details = accumulated_text.strip()
                fail_idx = cert_details.find("Server certificate verify failed")
                if fail_idx == -1:
                    fail_idx = cert_details.find("Certificate from VPN server")
                if fail_idx != -1:
                    cert_msg = cert_details[fail_idx:cert_match.start()].strip()
                else:
                    cert_msg = "The VPN server's SSL certificate could not be verified automatically."

                question = f"{cert_msg}\n\nDo you want to accept this certificate and continue connecting?"
                accepted = dialog_yesno(f"VPN Certificate - {vpn_name}", question)
                if accepted:
                    os.write(master, b"yes\n")
                    accumulated_text = ""
                else:
                    os.write(master, b"no\n")
                    kill_child()
                    sys.exit(130)
                continue

            # 2. Username prompt
            user_match = re.search(r"(?:^|\n)\s*(?:vpn\.user-name|vpn\.secrets\.username|User name|Username)\s*:\s*$", accumulated_text, re.IGNORECASE)
            if user_match:
                prompt_count += 1
                prefix = "Authentication failed. Please try again.\n\n" if auth_failed else ""
                prompt_label = f"{prefix}Enter username for {vpn_name}:"
                auth_failed = False
                ok, username = dialog_input(window_title, prompt_label)
                if ok:
                    os.write(master, (username + "\n").encode('utf-8'))
                    accumulated_text = ""
                else:
                    kill_child()
                    sys.exit(130)
                continue

            # 3. Password / Secret prompt
            pass_match = re.search(r"(?:^|\n)\s*(?:(?:vpn\.secrets\.)?(?:gateway-)?(?:password|passphrase|secret|pin)(?:\s*\([^)]*\))?)\s*:\s*$", accumulated_text, re.IGNORECASE)
            if pass_match:
                prompt_count += 1
                prompt_label = f"Enter password for {vpn_name}:"
                ok, password = dialog_password(window_title, prompt_label)
                if ok:
                    os.write(master, (password + "\n").encode('utf-8'))
                    accumulated_text = ""
                else:
                    kill_child()
                    sys.exit(130)
                continue

            # 4. 2FA / OTP / Token / Challenge prompt
            otp_match = re.search(r"(?:^|\n)\s*(?:challenge|response|passcode|token|otp|one-time password|verification code)\s*:\s*$", accumulated_text, re.IGNORECASE)
            if otp_match:
                prompt_count += 1
                prompt_label = f"Enter verification code / token for {vpn_name}:"
                ok, code = dialog_input(window_title, prompt_label)
                if ok:
                    os.write(master, (code + "\n").encode('utf-8'))
                    accumulated_text = ""
                else:
                    kill_child()
                    sys.exit(130)
                continue

            # 5. Generic fallback prompt: ends with ": " or "? " and no newline
            generic_match = re.search(r"(?:^|\n)\s*([^\n\r]+?)\s*[:\?]\s*$", accumulated_text)
            if generic_match and len(accumulated_text.splitlines()[-1].strip()) < 80:
                line = generic_match.group(1).strip()
                if not line.startswith("http") and not line.startswith("Connected") and not line.startswith("SSL"):
                    prompt_count += 1
                    if any(w in line.lower() for w in ["pass", "secret", "pin", "key"]):
                        ok, val = dialog_password(window_title, f"{line}:")
                    else:
                        ok, val = dialog_input(window_title, f"{line}:")
                    if ok:
                        os.write(master, (val + "\n").encode('utf-8'))
                        accumulated_text = ""
                    else:
                        kill_child()
                        sys.exit(130)
                    continue

            if prompt_count >= max_prompts:
                print("Exceeded maximum authentication attempts.", file=sys.stderr)
                kill_child()
                sys.exit(1)

    except KeyboardInterrupt:
        kill_child()
        sys.exit(130)
    finally:
        try:
            os.close(master)
        except OSError:
            pass

    _, status = os.waitpid(pid, 0)
    exit_code = os.waitstatus_to_exitcode(status)
    sys.exit(exit_code)

if __name__ == '__main__':
    main()
