alias TiendaAlbumes.Repo

Repo.query!("""
INSERT INTO artista VALUES
(1, 'Jeff Buckley', 'USA'),
(2, 'Sufjan Stevens', 'USA'),
(3, 'Slowdive', 'UK'),
(4, 'My Bloody Valentine', 'Ireland'),
(5, 'Cocteau Twins', 'UK'),
(6, 'Have a Nice Life', 'USA'),
(7, 'Godspeed You! Black Emperor', 'Canada'),
(8, 'Swans', 'USA'),
(9, 'Nick Drake', 'UK'),
(10, 'Elliott Smith', 'USA'),
(11, 'Mount Eerie', 'USA'),
(12, 'The Microphones', 'USA'),
(13, 'Björk', 'Iceland'),
(14, 'Aphex Twin', 'UK'),
(15, 'Boards of Canada', 'UK'),
(16, 'Burial', 'UK'),
(17, 'Tim Hecker', 'Canada'),
(18, 'Fennesz', 'Austria'),
(19, 'Talk Talk', 'UK'),
(20, 'Slint', 'USA'),
(21, 'American Football', 'USA'),
(22, 'Duster', 'USA'),
(23, 'Grouper', 'USA'),
(24, 'Lingua Ignota', 'USA'),
(25, 'Ichiko Aoba', 'Japan')
""")

Repo.query!("""
INSERT INTO album VALUES
(1, 'Grace', 1994, 1),
(2, 'Illinois', 2005, 2),
(3, 'Souvlaki', 1993, 3),
(4, 'Loveless', 1991, 4),
(5, 'Heaven or Las Vegas', 1990, 5),
(6, 'Deathconsciousness', 2008, 6),
(7, 'Lift Yr. Skinny Fists...', 2000, 7),
(8, 'To Be Kind', 2014, 8),
(9, 'Pink Moon', 1972, 9),
(10, 'Either/Or', 1997, 10),
(11, 'A Crow Looked at Me', 2017, 11),
(12, 'The Glow Pt. 2', 2001, 12),
(13, 'Homogenic', 1997, 13),
(14, 'Selected Ambient Works 85-92', 1992, 14),
(15, 'Music Has the Right to Children', 1998, 15),
(16, 'Untrue', 2007, 16),
(17, 'Ravedeath, 1972', 2011, 17),
(18, 'Endless Summer', 2001, 18),
(19, 'Spirit of Eden', 1988, 19),
(20, 'Spiderland', 1991, 20),
(21, 'LP1', 1999, 21),
(22, 'Stratosphere', 1998, 22),
(23, 'Dragging a Dead Deer...', 2008, 23),
(24, 'Caligula', 2019, 24),
(25, '0', 2020, 25)
""")

Repo.query!("""
INSERT INTO genero VALUES
(1, 'Rock', NULL),
(2, 'Indie Rock', 1),
(3, 'Shoegaze', 2),
(4, 'Dream Pop', 2),
(5, 'Folk', NULL),
(6, 'Singer-Songwriter', 5),
(7, 'Ambient', NULL),
(8, 'Electronic', NULL),
(9, 'Post-Rock', 1),
(10, 'Noise Rock', 1)
""")

Repo.query!("""
INSERT INTO album_genero VALUES
(1,6),(2,2),(3,3),(3,4),(4,3),(5,4),
(6,7),(7,9),(8,10),(9,6),(10,6),
(11,5),(12,2),(13,8),(14,7),(15,8),
(16,8),(17,7),(18,7),(19,9),(20,1),
(21,2),(22,7),(23,7),(24,10),(25,5)
""")

Repo.query!("""
INSERT INTO formato VALUES
(1, 'Vinilo'),
(2, 'CD')
""")

Repo.query!("""
INSERT INTO producto VALUES
(1,1,1,25.99,5),(2,1,2,12.99,10),
(3,2,1,30.00,3),(4,2,2,14.00,7),
(5,3,1,28.00,4),(6,3,2,13.00,6),
(7,4,1,35.00,2),(8,4,2,15.00,5),
(9,5,1,27.00,3),(10,5,2,12.00,8),
(11,6,1,40.00,2),(12,6,2,16.00,5),
(13,7,1,45.00,1),(14,7,2,18.00,4),
(15,8,1,50.00,2),(16,8,2,20.00,5),
(17,9,1,26.00,3),(18,9,2,11.00,7),
(19,10,1,29.00,4),(20,10,2,13.00,6),
(21,11,1,32.00,2),(22,11,2,15.00,5),
(23,12,1,31.00,3),(24,12,2,14.00,6),
(25,13,1,33.00,3),(26,13,2,15.00,7),
(27,14,1,36.00,2),(28,14,2,16.00,6),
(29,15,1,34.00,3),(30,15,2,14.00,8),
(31,16,1,38.00,2),(32,16,2,17.00,5),
(33,17,1,42.00,1),(34,17,2,18.00,4),
(35,18,1,30.00,3),(36,18,2,14.00,7),
(37,19,1,39.00,2),(38,19,2,16.00,5),
(39,20,1,28.00,3),(40,20,2,13.00,6),
(41,21,1,27.00,4),(42,21,2,12.00,7),
(43,22,1,29.00,3),(44,22,2,13.00,6),
(45,23,1,31.00,2),(46,23,2,14.00,5),
(47,24,1,35.00,2),(48,24,2,15.00,5),
(49,25,1,33.00,3),(50,25,2,14.00,6)
""")

Repo.query!("""
INSERT INTO proveedor VALUES
(1,'Vinyl Import GT','1111','vinylgt@mail.com','Guatemala'),
(2,'Analog Dreams','2222','analog@mail.com','USA'),
(3,'Obscure Records','3333','obscure@mail.com','UK'),
(4,'Rare Pressings Co.','4444','rare@mail.com','Germany'),
(5,'Ambient Distribution','5555','ambient@mail.com','Canada'),
(6,'Noise Supply','6666','noise@mail.com','USA'),
(7,'Indie Waves','7777','indie@mail.com','UK'),
(8,'Shoegaze Depot','8888','shoegaze@mail.com','France'),
(9,'Dream Pop Supply','9999','dreampop@mail.com','Spain'),
(10,'Post Rock Hub','1010','postrock@mail.com','Canada'),
(11,'Folk Roots Supply','1112','folk@mail.com','USA'),
(12,'Electronic Source','1212','electronic@mail.com','Germany'),
(13,'Experimental Audio','1313','exp@mail.com','Austria'),
(14,'Deep Cuts Records','1414','deepcuts@mail.com','USA'),
(15,'Underground Vinyl','1515','underground@mail.com','Mexico'),
(16,'Classic Pressings','1616','classic@mail.com','USA'),
(17,'Alt Sound Supply','1717','altsound@mail.com','UK'),
(18,'Modern Sound','1818','modern@mail.com','USA'),
(19,'Collector Editions','1919','collector@mail.com','Japan'),
(20,'Global Music Dist','2020','global@mail.com','Netherlands'),
(21,'Rare Waves','2121','rarewaves@mail.com','Ireland'),
(22,'Indie Archive','2223','archive@mail.com','USA'),
(23,'Noise Floor Dist','2323','noisefloor@mail.com','Sweden'),
(24,'Ambient Vault','2424','vault@mail.com','Norway'),
(25,'Minimal Sound Supply','2525','minimal@mail.com','Denmark')
""")

Repo.query!("""
INSERT INTO producto_proveedor VALUES
(1,1,15.00),(2,1,8.00),(3,7,18.00),
(4,7,9.00),(5,8,16.00),(6,8,8.00),
(7,4,22.00),(8,4,10.00),(9,9,15.00),
(10,9,7.00),(11,5,25.00),(12,5,12.00),
(13,10,28.00),(14,10,13.00),(15,6,30.00),
(16,6,15.00),(17,11,14.00),(18,11,6.50),
(19,7,16.00),(20,7,7.50),(21,14,18.00),
(22,14,9.00),(23,22,17.00),(24,22,8.00),
(25,12,19.00)
""")

Repo.query!("""
INSERT INTO cliente VALUES
(1,'Juan Perez','juan@mail.com','111','GT'),
(2,'Ana Lopez','ana@mail.com','222','GT'),
(3,'Luis Gomez','luis@mail.com','333','GT'),
(4,'Maria Ruiz','maria@mail.com','444','GT'),
(5,'Carlos Diaz','carlos@mail.com','555','GT'),
(6,'Sofia Morales','sofia@mail.com','666','GT'),
(7,'Pedro Castro','pedro@mail.com','777','GT'),
(8,'Laura Vega','laura@mail.com','888','GT'),
(9,'Diego Ramos','diego@mail.com','999','GT'),
(10,'Elena Cruz','elena@mail.com','101','GT'),
(11,'Cliente11','c11@mail.com','1111','GT'),
(12,'Cliente12','c12@mail.com','1212','GT'),
(13,'Cliente13','c13@mail.com','1313','GT'),
(14,'Cliente14','c14@mail.com','1414','GT'),
(15,'Cliente15','c15@mail.com','1515','GT'),
(16,'Cliente16','c16@mail.com','1616','GT'),
(17,'Cliente17','c17@mail.com','1717','GT'),
(18,'Cliente18','c18@mail.com','1818','GT'),
(19,'Cliente19','c19@mail.com','1919','GT'),
(20,'Cliente20','c20@mail.com','2020','GT'),
(21,'Cliente21','c21@mail.com','2121','GT'),
(22,'Cliente22','c22@mail.com','2222','GT'),
(23,'Cliente23','c23@mail.com','2323','GT'),
(24,'Cliente24','c24@mail.com','2424','GT'),
(25,'Cliente25','c25@mail.com','2525','GT')
""")

Repo.query!("""
INSERT INTO empleado VALUES
(1,'Empleado1','Cajero','111'),
(2,'Empleado2','Cajero','222'),
(3,'Empleado3','Cajero','333'),
(4,'Empleado4','Cajero','444'),
(5,'Empleado5','Cajero','555'),
(6,'Empleado6','Cajero','666'),
(7,'Empleado7','Cajero','777'),
(8,'Empleado8','Cajero','888'),
(9,'Empleado9','Cajero','999'),
(10,'Empleado10','Cajero','1010'),
(11,'Empleado11','Cajero','1111'),
(12,'Empleado12','Cajero','1212'),
(13,'Empleado13','Cajero','1313'),
(14,'Empleado14','Cajero','1414'),
(15,'Empleado15','Cajero','1515'),
(16,'Empleado16','Cajero','1616'),
(17,'Empleado17','Cajero','1717'),
(18,'Empleado18','Cajero','1818'),
(19,'Empleado19','Cajero','1919'),
(20,'Empleado20','Cajero','2020'),
(21,'Empleado21','Cajero','2121'),
(22,'Empleado22','Cajero','2222'),
(23,'Empleado23','Cajero','2323'),
(24,'Empleado24','Cajero','2424'),
(25,'Empleado25','Cajero','2525')
""")

Repo.query!("""
INSERT INTO compra VALUES
(1,'2026-01-01',1,1),(2,'2026-01-02',2,2),
(3,'2026-01-03',3,3),(4,'2026-01-04',4,4),
(5,'2026-01-05',5,5),(6,'2026-01-06',6,6),
(7,'2026-01-07',7,7),(8,'2026-01-08',8,8),
(9,'2026-01-09',9,9),(10,'2026-01-10',10,10),
(11,'2026-01-11',11,11),(12,'2026-01-12',12,12),
(13,'2026-01-13',13,13),(14,'2026-01-14',14,14),
(15,'2026-01-15',15,15),(16,'2026-01-16',16,16),
(17,'2026-01-17',17,17),(18,'2026-01-18',18,18),
(19,'2026-01-19',19,19),(20,'2026-01-20',20,20),
(21,'2026-01-21',21,21),(22,'2026-01-22',22,22),
(23,'2026-01-23',23,23),(24,'2026-01-24',24,24),
(25,'2026-01-25',25,25)
""")

Repo.query!("""
INSERT INTO detalle_compra VALUES
(1,1,1,25.99),(2,2,1,30.00),(3,3,1,28.00),
(4,4,1,35.00),(5,5,1,27.00),(6,6,1,40.00),
(7,7,1,45.00),(8,8,1,50.00),(9,9,1,26.00),
(10,10,1,29.00),(11,11,1,32.00),(12,12,1,31.00),
(13,13,1,33.00),(14,14,1,36.00),(15,15,1,34.00),
(16,16,1,38.00),(17,17,1,42.00),(18,18,1,30.00),
(19,19,1,39.00),(20,20,1,28.00),(21,21,1,27.00),
(22,22,1,29.00),(23,23,1,31.00),(24,24,1,35.00),
(25,25,1,33.00)
""")
