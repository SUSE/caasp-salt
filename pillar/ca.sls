mine_functions:
  ca.crt:
    mine_function: x509.get_pem_entries
    glob_path: /etc/pki/ca.crt
  sa.key:
    mine_function: x509.get_pem_entries
    glob_path: /etc/pki/sa.key
