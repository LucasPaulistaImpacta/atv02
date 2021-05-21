CREATE USER IF NOT EXISTS 'atv02'@'%' IDENTIFIED BY 'atv02p1$sw4rd';

GRANT ALL PRIVILEGES ON atv02.* TO 'atv02'@'%' IDENTIFIED BY 'atv02p1$sw4rd';

CREATE DATABASE IF NOT EXISTS atv02;
ALTER DATABASE atv02 DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;

USE atv02;
CREATE TABLE teste_cloud (
        id INT NOT NULL, 
        name VARCHAR(50) NOT NULL, 
        discipline VARCHAR(100) NOT NULL,
        PRIMARY KEY (id)
);
INSERT INTO teste_cloud (
    id,
    name,
    discipline
) 
VALUES (
    1,
    'Lucas Machado Paulista',
    'Infrastructure and Cloud Architecture'
);