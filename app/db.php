<?php

$databaseConfig = [
    'HOST' => getenv('DB_HOST'),
    'USR' => getenv('DB_USER'),
    'PASS' => getenv('DB_PASSWORD'),
    'DB' => getenv('DB_NAME'),
];

foreach ($databaseConfig as $name => $value) {
    if ($value === false || $value === '') {
        error_log("Missing required database environment variable for {$name}.");
        http_response_code(500);
        exit('データベースの接続設定がありません。');
    }

    define($name, $value);
}