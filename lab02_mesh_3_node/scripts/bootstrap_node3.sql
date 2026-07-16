-- Register node3
SELECT spock.node_create(
    node_name := 'node3',
    dsn := 'host=node3 port=5432 dbname=spock_db user=spock_user password=spock_password'
);

-- Add all tables to default replication set
SELECT spock.repset_add_all_tables('default', ARRAY['public']);
