#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo -t cactus

# Add changes to git.
git add -A

# Commit changes.
msg="rebuilding site `date +%Y-%m-%d:%H:%M:%S` 🌎"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master

# Push subtree
git subtree push --prefix=public git@github.com:tayhalla/blog.git gh-pages
