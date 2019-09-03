function Get-CurrentBranchName() {
    return &git rev-parse --abbrev-ref HEAD
}