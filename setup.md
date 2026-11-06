cd /workspaces/connectlocal/backend
npm run db:push -- --yes     # first time only: applies the payment migration
npm start


cd /workspaces/connectlocal/backend && npm run port:public
cd /workspaces/connectlocal/frontend/connect-local
tool/run_web_codespace.sh

cd /workspaces/connectlocal/frontend/connect-local
tool/run_web_codespace.sh admin
