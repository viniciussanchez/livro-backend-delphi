-- Executado apenas na primeira vez que o contêiner sobe (volume vazio).
-- Cada microsserviço terá o seu próprio banco de dados.

CREATE DATABASE event_db;
CREATE DATABASE customer_db;
CREATE DATABASE ticket_db;
