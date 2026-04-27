<?php

$config['imap_host'] = 'localhost:143';
$config['smtp_host'] = 'localhost:25';
$config['smtp_auth_type'] = '';
$config['username_domain'] = 'opensec.lab';

$config['db_dsnw'] = 'sqlite:////var/www/html/roundcube/config/sqlite.db';

$config['des_key'] = 'opsn-lab-mail-24charkey!';
$config['product_name'] = 'OPSN Mail';
$config['temp_dir'] = '/var/www/html/roundcube/temp';
$config['log_dir'] = '/var/www/html/roundcube/logs';

$config['enable_installer'] = false;
$config['plugins'] = array('archive', 'zipdownload');
