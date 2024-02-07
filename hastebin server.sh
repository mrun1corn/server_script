sudo apt update
sudo apt install -y nodejs npm
git clone --depth 1 https://github.com/seejohnrun/haste-server.git
cd haste-server
npm install
sudo npm install -g pm2
pm2 start server.js --name="haste-server"
pm2 startup
pm2 save
