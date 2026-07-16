-- Subscribe node3 to node1
SELECT spock.sub_create(
    subscription_name := 'sub_node3_node1',
    provider_dsn := 'host=node1 port=5432 dbname=spock_db user=spock_user password=spock_password',
    forward_origins := '{}'
);

-- Subscribe node3 to node2
SELECT spock.sub_create(
    subscription_name := 'sub_node3_node2',
    provider_dsn := 'host=node2 port=5432 dbname=spock_db user=spock_user password=spock_password',
    forward_origins := '{}'
);
