echo "Installing new relic!"

npm install newrelic
cp node_modules/newrelic/newrelic.js newrelic.js

sed -i -r "s/My Application/mewm blog/" newrelic.js
sed -i -r "s/info/trace/" newrelic.js 
sed -i -r "s/license key here/${1}/" newrelic.js 
sed -i "1ivar newrelic = require('newrelic');" index.js 