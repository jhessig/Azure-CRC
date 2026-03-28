locals {
  github_actions_cidrs = [
    for cidr in jsondecode(data.http.github_meta.response_body).actions :
    cidr
    if can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", cidr))
  ]
}
