-- Register node2
SELECT spock.node_create(
    node_name := 'node2',
    dsn := 'host=node2 port=5432 dbname=spock_db user=spock_user password=spock_password'
);

-- Add tasks table to default replication set
SELECT spock.repset_add_table('default', 'tasks');
