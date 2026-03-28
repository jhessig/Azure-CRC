locals {
  github_actions_cidrs = [
    for cidr in jsondecode(data.http.github_meta.response_body).actions :
    can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", cidr)) ?
    (
      tonumber(regex("/([0-9]{1,2})$", cidr)[0]) > 30 ?
      regex("^([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.)[0-9]{1,3}", cidr)[0] +
      tostring(parseint(regex("\\.([0-9]{1,3})/", cidr)[0], 10) - (parseint(regex("\\.([0-9]{1,3})/", cidr)[0], 10) % 4)) + "/30"
      : cidr
    ) : cidr
    if can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}/[0-9]{1,2}$", cidr))
  ]
}
