-- Register node1
SELECT spock.node_create(
    node_name := 'node1',
    dsn := 'host=node1 port=5432 dbname=spock_db user=spock_user password=spock_password'
);

-- Add all tables to default replication set
SELECT spock.repset_add_all_tables('default', ARRAY['public']);
