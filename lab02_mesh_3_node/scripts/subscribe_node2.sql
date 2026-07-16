-- Subscribe node2 to node1
SELECT spock.sub_create(
    subscription_name := 'sub_node2_node1',
    provider_dsn := 'host=node1 port=5432 dbname=spock_db user=spock_user password=spock_password',
    forward_origins := '{}'
);

-- Subscribe node2 to node3
SELECT spock.sub_create(
    subscription_name := 'sub_node2_node3',
    provider_dsn := 'host=node3 port=5432 dbname=spock_db user=spock_user password=spock_password',
    forward_origins := '{}'
);
