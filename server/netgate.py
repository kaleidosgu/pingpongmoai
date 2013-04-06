import socket
import threading
import sys
import json

class CtlCmdEnum:
    CONNECT = 1
    SEND = 2
    CLOSE = 3

def get_line(s):
    sepidx = s.find("\r\n")
    if sepidx == -1:
        return (None, s)
    line = s[0 : sepidx]
    s = s[sepidx + 2 : ]
    return (line, s)
def send_line_to_gate(lineObj):
    line = json.dumps(lineObj) + "\r\n"
    gate_socket.send(line)
def tunnel_client(idx, client_socket):
    line = {"idx" : idx, "cmd" : CtlCmdEnum.CONNECT}
    send_line_to_gate(line)
    buf = ''
    while True:
        rcvd = None
        try:
            rcvd = client_socket.recv(65536)
        except:
            pass
        if not rcvd:
            client_socket.close()
            line = {"idx" : idx, "cmd" : CtlCmdEnum.CLOSE}
            send_line_to_gate(line)
            break
        buf += rcvd
        line, buf = get_line(buf)
        if line != None:
            lineObj = {"idx" : idx, "cmd" : CtlCmdEnum.SEND, "line" : line}
            send_line_to_gate(lineObj)
def tunnel_gate():
    buf = ''
    while True:
        rcvd = gate_socket.recv(65536)
        if not rcvd:
            sys.exit(0)
        buf += rcvd
        line, buf = get_line(buf)
        if line != None:
            lineObj = json.loads(line)
            if lineObj["cmd"] == CtlCmdEnum.SEND:
                client_socket = client_sockets[lineObj["idx"]]
                try:
                    if client_socket.send(lineObj["line"] + "\r\n") < 1:
                        client_socket.close()
                except:
                    client_socket.close()
            elif lineObj["cmd"] == CtlCmdEnum.CLOSE:
                client_socket = client_sockets[lineObj["idx"]]
                del client_sockets[lineObj["idx"]]
                client_socket.close()
            else:
                assert(False)
gate_socket = socket.socket()
gate_socket.connect(("127.0.0.1", 54322))
server_socket = socket.socket()
server_socket.bind(("0.0.0.0", 54321))
server_socket.listen(50)
idx = 0
client_sockets = {}
threading.Thread(target = tunnel_gate).start()
while True:
    client_socket, peer_info = server_socket.accept()
    idx += 1
    client_sockets[idx] = client_socket
    threading.Thread(target = tunnel_client, args = (idx, client_socket)).start()
