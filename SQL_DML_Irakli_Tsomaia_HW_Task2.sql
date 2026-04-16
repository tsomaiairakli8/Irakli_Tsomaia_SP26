/*Task 2
 * a) Space consumption: before = 575 mb. after DELETE of 1/3 rows= 575 mb. After VACUUM = 383 mb. After TRUNCATE = 0 mb
 
 b) DELETE and TRUNCATE in terms of:
 	execution time - TRUNCATE is faster
 	disk space usage - after DELETE disk space usage is the same (DELETE keeps dead tuples on deleted rows). TRUNCATE frees space
	transaction behavior - DELETE deletes rows in table by going row-by-row. TRUNCATE works on table level
	rollback possibility DELETE can be rolled back. TRUNCATE can only be rolled back in postgresql, however it is not possible in Oracle or MySql

c) why DELETE does not free space immediately
	Answer: DELETE marks rows as 'dead' making them invisible for database. rows like that can be reused with INSERT or UPDATE command  
	why VACUUM FULL changes table size
	Answer: VACUUM FULL rewrites the table and gets rid of 'dead' rows all together. when new table with lesser rows is created its size is different
	why TRUNCATE behaves differently
	Answer: TRUNCATE does not need to scan rows as DELETE does. This cuts the time making TRUNCATE faster. TRUNCATE drops the table and only perserves tables schema
	how these operations affect performance and storage
	Answer: DELETE is slow to perform and it keeps storage space intact, VACUUM FULL is even slower and shrinks table by the ammount of rows deleted, 
	TRUNCATE is fast and sets the disk space to 0. In terms of locking the table DELETE locks table on row level, making it possible for other users to operate table
	TRUNCATE and VACUUM FULL locks full table and makes it unable for other users to acess the table untill operation is complete


 * */