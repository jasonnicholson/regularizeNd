# includes the repo .gitconfig with the local .git/config
git config --local include.path ../.gitconfig

# Install nodejs which comes with npm. I use NVM. I get it via winget:
# winget install --id CoreyButler.NVMforWindows
npm ci