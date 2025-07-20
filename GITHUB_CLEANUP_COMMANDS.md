# Clean Up Commands for GitHub Push

## 🚨 CRITICAL: Run These Commands Before Pushing

```bash
# 1. Remove all sensitive files
Remove-Item -Path ".env" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "applications\frontend\.env.local" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "terraform\environments\dev\terraform.tfvars" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "terraform\environments\dev\main_updated.tf" -Force -ErrorAction SilentlyContinue

# 2. Remove all node_modules directories
Get-ChildItem -Path . -Include node_modules -Recurse -Directory | Remove-Item -Recurse -Force

# 3. Move TASK files to docs folder
New-Item -Path "docs\tasks" -ItemType Directory -Force
Move-Item -Path "TASK*.md" -Destination "docs\tasks\" -Force

# 4. Verify clean status
git status

# 5. If files still appear, remove from git cache
git rm -r --cached .
git add .
git commit -m "Apply .gitignore and clean up repository"
```

## 📝 Files to Keep vs Remove

### ✅ KEEP These Files:
- `.env.template` (template with placeholders)
- `.env.example` files
- `terraform.tfvars.example`
- All source code files
- Documentation files
- GitHub workflows
- `.gitignore`

### ❌ REMOVE These Files:
- `.env` (actual environment file)
- `.env.local` (frontend environment)
- `terraform.tfvars` (actual terraform variables)
- All `node_modules/` directories
- `main_updated.tf` (duplicate file)
- Any `.zip` or build artifacts

## 🔍 Final Verification

Run this PowerShell command to ensure no sensitive files remain:

```powershell
# Search for potentially sensitive files
Get-ChildItem -Path . -Recurse -File | Where-Object {
    $_.Name -match "\.env$|\.tfvars$|\.pem$|\.key$" -and
    $_.FullName -notmatch "template|example" -and
    $_.FullName -notmatch "node_modules|\.git"
} | Select-Object FullName
```

## 🚀 Git Commands After Cleanup

```bash
# 1. Stage all changes
git add -A

# 2. Commit with clear message
git commit -m "Initial commit: AWS Education Platform

- Complete infrastructure as code using Terraform
- Frontend React application
- Backend services and Lambda functions
- Comprehensive documentation
- CI/CD with GitHub Actions"

# 3. Add remote (replace with your repository URL)
git remote add origin https://github.com/yourusername/aws-education-platform.git

# 4. Push to GitHub
git push -u origin main
```

## 📋 Post-Push Setup

After pushing to GitHub:

1. **Set up GitHub Secrets** in your repository settings:
   ```
   AWS_ACCESS_KEY_ID
   AWS_SECRET_ACCESS_KEY
   AWS_ACCOUNT_ID
   GITHUB_TOKEN
   ```

2. **Enable branch protection**:
   - Go to Settings → Branches
   - Add rule for `main` branch
   - Enable "Require pull request reviews"

3. **Set repository visibility**:
   - Keep private if contains proprietary logic
   - Can be public if generic educational platform

4. **Update README.md** with:
   - Your specific AWS account setup instructions
   - Any customizations made
   - Contact information

## ✅ Ready to Push Checklist

- [ ] All `.env` files removed
- [ ] All `terraform.tfvars` removed
- [ ] All `node_modules/` removed
- [ ] No hardcoded credentials in code
- [ ] `.gitignore` is comprehensive
- [ ] Documentation is complete
- [ ] GitHub repository created
- [ ] Local git repository initialized

Once all items are checked, your codebase is ready for GitHub! 🎉
