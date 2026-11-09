USE ie3a26v2_db;

CREATE TABLE products (
  sid varchar(255),
  sname varchar(255),
  scategory varchar(255),
  sphoto varchar(255),
  sprice int
);

INSERT INTO products VALUES
('c006','クリスマスプディング','ホール','cake01.jpg',2000),
('c0002','ブッシュド・ノエル','シートケーキ','cake02.jpg',250),
('c0003','イチゴとシブースドケーキ','ショートケーキ','cake03.jpg',400);