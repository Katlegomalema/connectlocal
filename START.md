# Start ConnectLocal (copy and paste)

Open 3 terminals in VS Code (the + in the terminal panel). Start them in this order.

## Terminal 1: backend (leave it running)
```bash
cd /workspaces/connectlocal/backend
npm start
```
Wait for `Server started`.

## Terminal 2: make the backend public, then the app (port 8080)
```bash
cd /workspaces/connectlocal/backend && npm run port:public
cd /workspaces/connectlocal/frontend/connect-local && tool/run_web_codespace.sh
```
Open the link it prints, then press Ctrl+Shift+R.

## Terminal 3: admin site (port 8081, only if needed)
```bash
cd /workspaces/connectlocal/frontend/connect-local && tool/run_web_codespace.sh admin
```

## If something goes wrong
```bash
# "can't reach the server": make port 3000 public again (needed after every backend restart)
cd /workspaces/connectlocal/backend && npm run port:public

# "Port 8080 is already in use"
kill $(lsof -t -i:8080)

# "Port 8081 is already in use"
kill $(lsof -t -i:8081)
```
Stop everything: Ctrl+C in each terminal. More detail: SETUP.md.
