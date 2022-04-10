	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,er"" and\"", test 2,, abc,'
	                                      ,p_keep_nulls => 'N', p_strip_dquote => 'Y'
	                                   )
	                     );
/*                       
"whatev,er" and"
test 2
abc
*/
	 -- see impact of trailing comma on number of fields
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,er"" and\"", , test 2,, test3 ,abc,'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
/*
"""whatev,er"" and\""

test 2

test3
abc

*/
	 -- see impact of NO trailing comma on number of fields
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,er"" and\"", , test 2,, test3 ,abc'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
/*
"""whatev,er"" and\""

test 2

test3
abc
*/
	 -- backwacked commas in non quoted strings plus trailing ,
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev,e\"r"" and\"", , te\,st 2,, test3\, ,abc,'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
	                                   )
	                     );
/*
"""whatev,e\"r"" and\""

te,st 2

test3,
abc

*/
	 SELECT * FROM TABLE(app_csv_pkg.split_csv('123.55,,abcdef,an excel unquoted string with a backwacked comma\, plus more in one field,"a true csv double quoted field with embedded "" and trailing space "'
	                                 )
	                    );
/*
123.55
abcdef
an excel unquoted string with a backwacked comma, plus more in one field
a true csv double quoted field with embedded " and trailing space 
*/

------------------ pipes ------------------------


	 select * from TABLE(app_csv_pkg.split_csv('"""whatev|er"" and\""| test 2|| abc|'
	                                      ,p_keep_nulls => 'N', p_strip_dquote => 'Y'
                                          ,p_separator => '|'
	                                   )
	                     );
/*                       
"whatev|er" and"
test 2
abc
*/
	 -- see impact of trailing comma on number of fields
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev|er"" and\""| | test 2|| test3 |abc|'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
                                          ,p_separator => '|'
	                                   )
	                     );
/*
"""whatev|er"" and\""

test 2

test3
abc

*/
	 -- see impact of NO trailing comma on number of fields
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev|er"" and\""| | test 2|| test3 |abc'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
                                          ,p_separator => '|'
	                                   )
	                     );
/*
"""whatev|er"" and\""

test 2

test3
abc
*/
	 -- backwacked pipes in non quoted strings plus trailing |
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev|e\"r"" and\""| | te\|st 2|| test3\| |abc|'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
                                          ,p_separator => '|'
	                                   )
	                     );
/*
"""whatev|e\"r"" and\""

te|st 2

test3|
abc

*/
	 SELECT * FROM TABLE(app_csv_pkg.split_csv('123.55||abcdef|an excel unquoted string with a backwacked pipe=>\| plus more in one field|"a true csv double quoted field with embedded "" and trailing space "'
                                          ,p_separator => '|'
	                                 )
	                    );
/*
123.55
abcdef
an excel unquoted string with a backwacked pipe=>| plus more in one field
a true csv double quoted field with embedded " and trailing space 
*/

----------------- caret --------------
	 -- backwacked caret in non quoted strings plus trailing caret
	 select * from TABLE(app_csv_pkg.split_csv('"""whatev^e\"r"" and\""^ ^ te\^st 2^^ test3\^ ^abc^'
	                                      ,p_keep_nulls => 'Y', p_strip_dquote => 'N'
                                          ,p_separator => '^'
	                                   )
	                     );
/*
"""whatev^e\"r"" and\""

te\^st 2

test3\^
abc

*/
	 SELECT * FROM TABLE(app_csv_pkg.split_csv('123.55^^abcdef^an excel unquoted string with a backwacked caret=>\^ plus more in one field^"a true csv double quoted field with embedded "" and trailing space "'
                                          ,p_separator => '^'
	                                 )
	                    );
/*
123.55
abcdef
an excel unquoted string with a backwacked caret=>\^ plus more in one field
a true csv double quoted field with embedded " and trailing space 
*/
