api:
  server:
    external_fqdn: null
    extra_names:   []
    extra_ips:     []
  admission_webhook:
    enabled: False
    cert: ''
    key: ''
  audit:
    log:
      enabled: false
      maxsize: '10'
      maxage: '15'
      maxbackup: '20'
      policy: '' # note well, an empty policy file would cause the apiserver to NOT start
