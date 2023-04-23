# perlish_util

- Transform regular expression string from Perl Extended format to Oracle regex string
- map a string transformation onto list elements
- join string elements into single string with separator
- sort
- get
- combine elements of two lists into new list

## perlish_util_udt

It isn't Perl, but it makes some Perlish things a bit easier in PL/SQL. 

> There is valid argument
that when you are programming in a language you should use the facilities of that language, 
and that attempting to layer the techniques of another language upon it is a bad idea. I see the logic
and partially agree. I expect those who later must support my work that uses this utility will curse me. Yet
PL/SQL really sucks at some string and list related things. This uses valid PL/SQL object techniques
to manipulate strings and lists in a way that is familiar to Perl hackers. 

A *perlish_util_udt* object instance holds an *arr_varchar2_udt* collection attribute which you will use when employing the following member methods;

- map
- join
- join2clob
- sort
- get
- count
- combine

All member methods except *get* and *count* have static alternatives using *arr_varchar2_udt* parameters and return types, so you
are not forced to use the Object Oriented syntax.

It also has a static method named *transform_perl_regexp* that has nothing to do with arrays/lists, but is Perlish.

Most of the member methods are chainable which is handy when you are doing a series of operations.

### Examples

Example 1:
```sql
    SELECT perlish_util_udt(arr_varchar2_udt('one', 'two', 'three', 'four')).sort().join(', ') FROM dual;
    -- Or using split_csv version of the constructor
    SELECT perlish_util_udt('one, two, three, four').sort().join(', ') FROM dual;
```
Output:

    four, one, three, two

Example 2:
```sql
    SELECT perlish_util_udt('id, type').map('t.$_ = q.$_').join(' AND ') FROM dual;
```
Output:

    t.id = q.id AND t.type = q.type

Example 3:
```sql
    SELECT perlish_util_udt('id, type').map('  t.$_ = q.$_').join(',') FROM dual;
```
Output:

    "  t.id = q.id,
        t.type = q.type"

Example 4:
```sql
    SELECT perlish_util_udt('id, type').map('x.p.get($##index_val##) AS "$_"').join(', ') FROM dual;
```
Output:

    x.p.get(1) AS "id", x.p.get(2) AS "type"

There are static versions of all of the methods. You do not have to create an
object or use the object method syntax. You can use each of them independently as if they
were in a package named *perlish_util_udt*.

Example 0(static) (*LISTAGG* functionality returning CLOB, no 4000 char limitation):

```sql
SELECT perlish_util_udt.join2clob( CAST( COLLECT(column_name ORDER BY column_id) AS arr_varchar2_udt ), ', ') AS collist
FROM dba_tab_columns
WHERE owner = 'HR' AND table_name = 'EMPLOYEES';
```
Output:

    EMPLOYEE_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE_NUMBER, HIRE_DATE, JOB_ID, SALARY, COMMISSION_PCT, MANAGER_ID, DEPARTMENT_ID

Example 1(static):
```sql
    SELECT perlish_util_udt.join( 
                perlish_util_udt.sort( 
                        arr_varchar2_udt('one', 'two', 'three', 'four') 
                ), 
                ', ' 
           ) 
    FROM dual;
    -- Or
    SELECT perlish_util_udt.join( 
                perlish_util_udt.sort( 
                    app_csv_pkg.split_csv('one, two, three, four') 
                )
                , ', ' 
            ) 
    FROM dual;
```
Output:

    four, one, three, two

Example 2(static):
```sql
    SELECT perlish_util_udt.join( 
                perlish_util_udt.map('t.$_ = q.$_'
                                    , arr_varchar2_udt('id', 'type')
                )
                , ' AND '
           )
    FROM dual;
```
Output:

    t.id = q.id AND t.type = q.type

### Type Specification

```sql
CREATE OR REPLACE TYPE perlish_util_udt FORCE
AS OBJECT (
    arr     &&d_arr_varchar2_udt.
    /*
    -- this one is provided by Oracle automatically as the default constructor
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
        p_arr    &&d_arr_varchar2_udt.
    ) RETURN SELF AS RESULT
    */
        ,CONSTRUCTOR FUNCTION perlish_util_udt(
         p_csv              VARCHAR2
        ,p_separator        VARCHAR2    DEFAULT ','
	    ,p_keep_nulls       VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote     VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
        ,p_expected_cnt     NUMBER      DEFAULT 0
    ) RETURN SELF AS RESULT
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
         p_csv              CLOB
        ,p_separator        VARCHAR2    DEFAULT ','
	    ,p_keep_nulls       VARCHAR2    DEFAULT 'N'
	    ,p_strip_dquote     VARCHAR2    DEFAULT 'Y' -- also unquotes \" and "" pairs within the field to just "
        ,p_expected_cnt     NUMBER      DEFAULT 0
    ) RETURN SELF AS RESULT
    -- a weirdo constructor. Creates array with each value containing p_map_string
    -- except the token '$##index_val##' is replaced with an index number starting
    -- with p_first and going through p_last
    -- Example: v_str := perlish_util_udt(p_map_string => 'x.pu_udt.get($##index_val##) AS C$##index_val##'
    --                                    , p_last => 5
    --                                   ).join(CHR(10)||',');
    --
    ,CONSTRUCTOR FUNCTION perlish_util_udt(
        p_map_string        VARCHAR2
        ,p_last             NUMBER
        ,p_first            NUMBER      DEFAULT 1
    ) RETURN SELF AS RESULT

    -- all are callable in a chain if they return perlish_util_udt; otherwise must be end of chain
    -- get the object member collection
    ,MEMBER FUNCTION get RETURN &&d_arr_varchar2_udt.
    -- get a collection element
    ,MEMBER FUNCTION get(
        p_i             NUMBER
    ) RETURN VARCHAR2
    -- get count of collection elements
    ,MEMBER FUNCTION count RETURN NUMBER
    ,STATIC FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_arr          &&d_arr_varchar2_udt.
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
    ) RETURN &&d_arr_varchar2_udt.
    ,MEMBER FUNCTION map(
        p_expr          VARCHAR2 -- not an anonymous block
        ,p_             VARCHAR2 DEFAULT '$_' -- the string that is replaced in p_expr with array element
        -- example: v_arr := v_perlish_util_udt(v_arr).map('t.$_ = q.$_');
    ) RETURN perlish_util_udt
    -- combines elements of 2 arrays based on p_expr and returns a new array
    ,STATIC FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_a        &&d_arr_varchar2_udt.
        ,p_arr_b        &&d_arr_varchar2_udt.
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
    ) RETURN &&d_arr_varchar2_udt.
    ,MEMBER FUNCTION combine(
        p_expr          VARCHAR2 -- not anonymous block. $_a_ and $_b_ are replaced
        ,p_arr_b        &&d_arr_varchar2_udt.
        ,p_a            VARCHAR2 DEFAULT '$_a_'
        ,p_b            VARCHAR2 DEFAULT '$_b_'
        -- example: v_arr := v_perlish_util_udt(v_arr).combine(q'['$_a_' AS $_b_]', v_second_array);
    ) RETURN perlish_util_udt

    -- join the elements into a string with a separator between them
    ,STATIC FUNCTION join(
        p_arr           &&d_arr_varchar2_udt.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,MEMBER FUNCTION join(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN VARCHAR2
    ,STATIC FUNCTION join2clob(
        p_arr           &&d_arr_varchar2_udt.
        ,p_separator    VARCHAR2 DEFAULT ','
    ) RETURN CLOB
    ,MEMBER FUNCTION join2clob(
        p_separator     VARCHAR2 DEFAULT ','
    ) RETURN CLOB

    -- yes these are ridiculous, but I want it
    ,STATIC FUNCTION sort(
        p_arr           &&d_arr_varchar2_udt.
        ,p_descending   VARCHAR2 DEFAULT 'N'
    ) RETURN &&d_arr_varchar2_udt.
    ,MEMBER FUNCTION sort(
        p_descending    VARCHAR2 DEFAULT 'N'
    ) RETURN perlish_util_udt
    --
    -- these are really standalone but this was a good place to stash them
    --
    ,STATIC FUNCTION transform_perl_regexp(p_re CLOB)
        RETURN CLOB DETERMINISTIC
    ,STATIC FUNCTION transform_perl_regexp(p_re VARCHAR2)
        RETURN VARCHAR2 DETERMINISTIC
);
```
### CONSTRUCTOR perlish_util_udt

You can call the default constructor with an *arr_varchar2_udt* collection, or you can call
the custom constructor that takes a VARCHAR2 or CLOB parameter which will be split on commas by *app_csv_pkg.split_csv*.

In the second form the the optional arguments are from *app_csv_pkg.split_csv*. See documentation on
that package for additional detail.

#### Parameters Default Constructor

- ARR_VARCHAR2_UDT
    -- a nested table collection of VARCHAR2(4000) strings

#### Parameters for *split_csv* Constructor

- p_csv VARCHAR2 or CLOB
    - A string expected to contain CSV data, generally comma separated and possibly double quoted
- p_separator VARCHAR2
    - The character between fields in the CSV data. Default comma.
- p_keep_nulls VARCHAR2
    - If you want empty (NULL string) entries in your array, set this to 'Y'. You could want this if you need placeholders or want actual NULL values to be used for the element. The default is 'N' to throw out NULL values from the CSV string.
- p_strip_dquote VARCHAR2
    - By default we strip the enclosing double quote marks for the field value if present. This also causes embedded occurences of `""` or `\\"` to be de-quoted. A value of 'N' for *p_strip_dquote* will leave double quoted strings with escaped double quotes intact.
- p_expected_cnt NUMBER
    - an optimization you generally will not be concerned with. See *app_csv_pkg* documentation for details

#### Parameters for Mapping Constructor

- p_map_string VARCHAR2
    - A string that will populate each value of the array. On every instance the placeholder '$##index_val##' is replaced by the string of the numeric value between *p_first* and *p_last*. Note that this is not necessarily the same as the index into the array which will always start with 1.
- p_last NUMBER
    - The last value in the list
- p_first NUMBER
    - The first value in the list. Defautl is 1.

##### Example

```sql
    v_str := perlish_util_udt(p_map_string => 'x.pu.get($##index_val##) AS c$##index_val##'
                              ,p_last => 3
                             ).join(CHR(10)||',');
```
String v_str will contain:

    x.pu.get(1) AS c1
    ,x.pu.get(2) AS c2
    ,x.pu.get(3) AS c3

### join

The array elements are joined together with a comma separator (or value you provide) returning a single string.
It works pretty much the same as Perl *join*.

#### Parameters

- p_separator VARCHAR2
    - Value to place between array elements while constructing the string that is returned. The default is ',', but you might want something like `CHR(10)||'    ,'` to make it pretty.

#### Discussion

You could do the same thing using *LISTAGG* in a SQL statement as long as the result was under 4000 characters.
The variant *join2clob* returns a CLOB so you are not limited in the size of the resulting string.

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    v1  VARCHAR2(4000);
BEGIN
    SELECT LISTAGG(column_value,';') INTO v1 FROM TABLE(a1);
    DBMS_OUTPUT.put_line(v1);
END;
```
Output:

    abc;def

Contrast that with the following and consider you could chain additional methods if needed.

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    v1  VARCHAR2(4000);
BEGIN
    v1 := perlish_util_udt(a1).join(';');
    DBMS_OUTPUT.put_line(v1);
    -- or --
    v1 := perlish_util_udt.join(a1, ';');
    DBMS_OUTPUT.put_line(v1);
END;
```

### join2clob

Same as *join*, but returns CLOB. In PL/SQL it will not matter as VARCHAR2 and CLOB are equivalent
in most situations. In SQL you will need *join2clob*
if the returned string is longer than 4000 characters, something users of *LISTAGG* 
have likely been annoyed by before. There is a well known workaround to the 4000 character limitation
of *LISTAGG* using *XMLAGG*. We provide another way with *join2clob*.

### sort

*Sort* calls the SQL engine to sort the incoming list and returns a new
*perlish_util_udt* object with the sorted results.

#### Parameters

- p_descending VARCHAR2
    - Default is 'N'. Provide 'Y' for sorting the array in descending order.

#### Discussion

I almost didn't provide this but the fact that you have to reach out to the SQL engine
to do a sort in PL/SQL is sort of annoying (you decide whether the pun is intended). 

The traditional way:

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    a2  arr_varchar2_udt;
BEGIN
    SELECT column_value BULK COLLECT INTO a2 
    FROM TABLE(a1)
    ORDER BY column_value
    ;
END;
```

The perlish way:

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    a2  arr_varchar2_udt;
BEGIN
    a2 := perlish_util_udt(a1).sort().get();
    -- or --
    a2 := perlish_util_udt.sort(a1);
END;
```
### map

The list elements are transformed by replacing the token '$\_'
with the each list element as many times
as it appears in the *p_expr* string. 

Likewise, if the string '$##index_val##' occurs in the string, it is replaced with the array
index value.

It returns a new *perlish_util_udt* object with the transformed elements.

>Note that this is just an expression version of the Perl *map*
functionality. We are not doing an anonymous block or anything really fancy. We could, but I do
not think it would be a good idea. Keep your expectations low.

#### Parameters

- p_expr VARCHAR2
    - The string that is put into the output array with placeholders replaced by the value of the input array (and optionally the index value).
- p_ VARCHAR2
    - If you do not like the default placeholder of '$\_', you can specify your own. The special placeholder name '###index_val##' cannot be changed. If you want to be able to change it, put in a pull request to add another parameter.

#### Discussion

If you are going to do both *map* and *join*, you could use *LISTAGG* in a SQL statement
to accomplish it. 

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc', 'def');
    v1  VARCHAR2(4000);
BEGIN
    SELECT LISTAGG('This is the story of '||column_value, ' and ') INTO v1
    FROM TABLE(a1)
    ;
    DBMS_OUTPUT.put_line(v1);

    -- compared to the perlish way
    v1 := perlish_util_udt(a1).map('This is the story of $_').join(' and ');
    DBMS_OUTPUT.put_line(v1);
END;
```

### combine

Given an expression:

    '$_a_ combines with $_b_'

and the input list from the object instance plus the input array named *p_arr_b*,
it loops through the elements substituting the value from the object instance array
wherever '$\_a\_' occurs in the string, and the value from the array named *p_arr_b*
wherever '$\_b\_' occurs in the string. The result is stuffed into the return array
at the same index. 

It returns a new *perlish_util_udt* object with the transformed/combined elements.

#### Parameters

- p_expr VARCHAR2
    - A string that will be put into each element of the output array. The values '$\_a\_' and '$\_b\_' are replaced by the corresponding elements of the two input arrays (first of which is the instance invoking the method).
- p_arr_b ARR_VARCHAR2_UDT
    - The second array of elements -- the ones that replace '$\_b\_'. Note that this is not a *perlish_util_udt* object. If you have one named *v_pu_b* you will specify the parameter as `p_arr_b => v_pu_b.get -- or v_pu_b.arr`.
- p_a   VARCHAR2
    - The placeholder string for elements from the invoking instance array. Default is '$\_a\_'.
- p_b   VARCHAR2
    - The placeholder string for elements from the second array, parameter *p_arr_b*. Default is '$\_b\_'.

#### Discussion

Not really a Perl thing because in Perl we would build anonymous arrays/hashes on the fly to do it, 
but I often find myself needing to combine elements of two
lists into a new string value list. It works kind of like map 
and kind of like sort does with the $a and $b variables for different elements (well, different
elements in a single list, but hopefully you get the idea). 

You can use different placeholders than '$\_a\_' by specifying 
the placholder strings in the arguments *p_a* and *p_b*.

Example:

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc','def');
    a2  arr_varchar2_udt := arr_varchar2_udt('xyz','uvw');
    a3  arr_varchar2_udt;
BEGIN
    a3 := perlish_util_udt(a1).combine('$_a_ combines with $_b_', a2).get;
    -- or --
    a3 := perlish_util_udt.combine('$_a_ combines with $_b_', a1, a2);

END;
```

For our example if the first element of our object array was 'abc'
and the first element of *p_arr_b* was 'xyz' we would get

    abc combines with xyz

in the first element of the returned array object. Contrast with the SQL way to do the same thing.

```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc','def');
    a2  arr_varchar2_udt := arr_varchar2_udt('xyz','uvw');
    a3  arr_varchar2_udt;
BEGIN
    WITH a1 AS (
        SELECT rownum AS rn1, column_value AS v1
        FROM TABLE(a1)
    ), a2 AS (
        SELECT rownum AS rn2, column_value AS v2
        FROM TABLE(a2)
    )
    SELECT v1||' combines with '||v2 BULK COLLECT INTO a3
    FROM a1
    INNER JOIN a2
        ON rn2 = rn1
    ORDER BY rn1
    ;
    FOR i IN 1..a3.COUNT
    LOOP
        DBMS_OUTPUT.put_line(a3(i));
    END LOOP;
END;
```
Yeah, nobody would do that.

> The above depends upon an assumption that *rownum* is assigned in the order that elements
appear in the collection. I believe that will be true based on the way it was almost certainly
implemented; however, I cannot find comfirmation
in the documentation and have read Tom Kyte say many times that the only way you can depend
upon the order of rows returned by a SELECT is to use an ORDER BY. This seems safe enough though.
Everybody does it.

More realistically you would write the routine in PL/SQL.
```sql
DECLARE
    a1  arr_varchar2_udt := arr_varchar2_udt('abc','def');
    a2  arr_varchar2_udt := arr_varchar2_udt('xyz','uvw');
    a3  arr_varchar2_udt;
BEGIN
    a3 := arr_varchar2_udt();
    a3.EXTEND(a1.COUNT);
    FOR i IN 1..a1.COUNT
    LOOP
        a3(i) := a1(i)||' combines with '||a2(i);
    END LOOP;

    FOR i IN 1..a3.COUNT
    LOOP
        DBMS_OUTPUT.put_line(a3(i));
    END LOOP;
END;
```

Now you do not need to. You can use *combine*.

### get

The method with no arguments returns the collection from the object so you don't need to
put your grubby paws on it directly.

The override method that takes a NUMBER argument returns an element of the collection. Not only does this allow us
to avoid accessing the member attribute directly, it allows us to get a value from the collection in SQL! See
examples below.

### count

Returns the collection count from member collection.

### transform_perl_regexp

A function to treat the input value as a Perl-style regular expression with
embedded comments and whitespace that must be stripped as if it were used
with 'x' option in Perl. Although Oracle regular expression functions have an 'x'
modifier, it does not handle comments nor can it strip whitespace without removing
newline and tab characters.

Comments are identified by a Posix [:blank:] character (space or tab for practical purposes)
followed by either '#' or '--'. Once that pattern is found on a line, it and all following
charcters up to the end of the line (newline not included) are removed. If you need to use ' #'
or ' --' in your pattern, you will have to find a way to protect it (hint: put either the space
or comment char in a character class).

Following removal of comments, all whitespace (including newline) is removed as would be true for the 'x' modifier.

Finally, *transform_perl_regexp* translates '\t', '\r' and '\n' tokens to the corresponding literal
values (CHR(9), CHR(13), and CHR(10)) (after stripping whitespace!). It will not replace one
of these if the preceding character is a '\\'. That is intended to let you write '\\\n' such that the 
backwack is protected. It isn't clever enough to figure out '\\\\\n'. Tough. Write your own parser.

This means you can write a regular expression that looks like this:

```sql
    v_re := perlish_util_udt.transform_perl_regexp('
(                               -- capture in \1
  (                             -- going to group 0 or more of these things
    [^"\n]+                     -- any number of chars that are not dquote or newline
    |                           
    "                           -- double quoted string start
        (                       -- just grouping. Order of the next set of things matters. Longest first
            ""                  -- literal "" which is a quoted dquoute within dquote string
            |
            \\"                 -- a backwacked dquote (but need to backwack the backwack)
            |
            [^"]                -- any character not the above two constructs or a dquote
        )*                      -- zero or more of those chars or constructs 
   "                            -- closing dquote
  )*                            -- zero or more strings on a single "line" that could include newline in dquotes
)                               -- end capture \1
(                               -- just grouping 
    $|\n                        -- require match newline or string end 
)                               -- close grouping
');
```
and have the RE that you hand to the Oracle procedure appear as

    (([^"
    ]+|"(""|\\"|[^"])*")*)($|
    )

## perlish_util_pkg

One of the coolest things in Perl is the hash slice assignment. *perlish_util_pkg* implements the equivalent
of a Perl hash slice and hash slice assignment. It throws in *indicies_of*, *values_of*, and *pairs_of* methods.

Oracle 21c provides functionality in FOR loop iteration controls and qualified expressions
that will reduce the value of these functions and procedures.

Until then the package is needed to supplement *perlish_util_udt* because 
a user defined type cannot work with associative arrays (aka vectors).
Not only can an Oracle object type not contain an associative array, object type methods may not use them as parameters 
or return types either. 

I got excited when I saw Oracle 21c supported PL/SQL types in non-persistable object types,
but it is only the scalar types like boolean and binary\_integer. Bah!

#### Example 1

```sql
DECLARE
    my_hash perlish_util_pkg.t_hash;
    v_i VARCHAR2(4000);
BEGIN
    my_hash := perlish_util_pkg.hash_slice_assign(perlish_util_udt('a,b,c,d')
                                                , perlish_util_udt('one, two, three, four')
                                                 );
    v_i := my_hash.FIRST;
    WHILE v_i IS NOT NULL LOOP
        DBMS_OUTPUT.put_line('my_hash('||v_i||') is '||my_hash(v_i));
        v_i := my_hash.NEXT(v_i);
    END LOOP;
    DBMS_OUTPUT.put_line(perlish_util_udt( perlish_util_pkg.hash_slice(my_hash
                                                    , perlish_util_udt('b,d')) ).join(', ') 
                                                                      );
END;
```
Output:

    my_hash(a) is one
    my_hash(b) is two
    my_hash(c) is three
    my_hash(d) is four
    two, four

#### Example 2

```sql
DECLARE
    my_hash perlish_util_pkg.t_hash;
    v_arr   arr_varchar2_udt;
BEGIN
    my_hash := perlish_util_pkg.hash_slice_assign(perlish_util_udt('a,b,c,d')
                                                , perlish_util_udt('one, two, three, four')
                                                 );
    v_arr := perlish_util_pkg.indicies_of(my_hash);
    DBMS_OUTPUT.put_line(perlish_util_udt(v_arr).sort(p_descending => 'Y').join(', '));
    v_arr := perlish_util_udt(v_arr).sort('Y').get();
    -- yeah, yeah. there are other ways to do this particular thing in plsql. It is an example
    FOR i IN 1..v_arr.COUNT
    LOOP
        DBMS_OUTPUT.put_line(my_hash( v_arr(i) ));
    END LOOP;
END;
```
Output:

    d, c, b, a
    four
    three
    two
    one

#### Example 3

```sql
DECLARE
    my_hash perlish_util_pkg.t_hash;
    v_src   SYS_REFCURSOR;
    v_idx   VARCHAR2(4000);
BEGIN
    OPEN v_src FOR 
        SELECT department_name, TO_CHAR(department_id)
        FROM hr.departments
        ORDER BY department_name
        ;
    my_hash := perlish_util_pkg.cursor2hash(v_src);
    v_idx := my_hash.FIRST;
    WHILE v_idx IS NOT NULL
    LOOP
        DBMS_OUTPUT.put_line(v_idx||' IS '||my_hash(v_idx));
        v_idx := my_hash.next(v_idx);
    END LOOP;
END;
```

Output:

    Accounting IS 110
    Administration IS 10
    Benefits IS 160
    Construction IS 180
    Contracting IS 190
    Control And Credit IS 140
    Corporate Tax IS 130
    Executive IS 90
    Finance IS 100
    Government Sales IS 240
    Human Resources IS 40
    IT IS 60
    IT Helpdesk IS 230
    IT Support IS 210
    Manufacturing IS 170
    Marketing IS 20
    NOC IS 220
    Operations IS 200
    Payroll IS 270
    Public Relations IS 70
    Purchasing IS 30
    Recruiting IS 260
    Retail Sales IS 250
    Sales IS 80
    Shareholder Services IS 150
    Shipping IS 50
    Treasury IS 120

### Package Specification

```sql
    -- Oracle 21c will make these mostly obsolete.

    TYPE t_hash IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(4000);
    FUNCTION hash_slice(
         p_hash     t_hash
        ,p_arr_a    arr_varchar2_udt
    ) RETURN arr_varchar2_udt
    ;
    FUNCTION hash_slice(
         p_hash     t_hash
        ,p_arr_a    perlish_util_udt
    ) RETURN arr_varchar2_udt
    ;
    PROCEDURE hash_slice_assign(
         p_hash     IN OUT NOCOPY t_hash
        ,p_arr_a    arr_varchar2_udt
        ,p_arr_b    arr_varchar2_udt
    );
    FUNCTION hash_slice_assign(
         p_arr_a    arr_varchar2_udt
        ,p_arr_b    arr_varchar2_udt
    ) RETURN t_hash
    ;
    PROCEDURE hash_slice_assign(
         p_hash     IN OUT NOCOPY t_hash
        ,p_arr_a    perlish_util_udt
        ,p_arr_b    perlish_util_udt
    );
    FUNCTION hash_slice_assign(
         p_arr_a    perlish_util_udt
        ,p_arr_b    perlish_util_udt
    ) RETURN t_hash
    ;

    FUNCTION cursor2hash(
        p_src   SYS_REFCURSOR
    ) RETURN t_hash
    ;
    FUNCTION query2hash(
        p_query CLOB
    ) RETURN t_hash
    ;

    FUNCTION indicies_of(
         p_hash     t_hash
    ) RETURN arr_varchar2_udt
    ;
    FUNCTION values_of(
         p_hash     t_hash
    ) RETURN arr_varchar2_udt
    ;

    FUNCTION pairs_of(
        p_hash      t_hash
    ) RETURN arr_arr_varchar2_udt
    ;
    PROCEDURE pairs_of(
        p_hash          t_hash
        ,p_indicies OUT arr_varchar2_udt
        ,p_values   OUT arr_varchar2_udt
    )
    ;

    FUNCTION get_cursor_from_collections(
        p_arr_arr       arr_perlish_util_udt
        ,p_skip_rows    NUMBER := 0
        ,p_trim_rows    NUMBER := 0
    ) RETURN SYS_REFCURSOR
    ;
    FUNCTION arr_perlish_from_arr_varchar2(
        p_arr_arr       &&d_arr_arr_varchar2_udt.
    ) RETURN arr_perlish_util_udt
    ;

```

### get_cursor_from_collections

Builds a query string that selects rows from your collection of collections, then
for each row builds a list of column names C1, C2, ...

The WHERE clause can skip the first (or first few) records and last (or last few) records
via the parameters *p_skip_rows* and *p_trim_rows*.

It opens and returns a SYS_REFCURSOR using the query string it built, binding the collection and
counts to it.

#### Parameters

- p_arr_arr ARR_PERLISH_UTIL_UDT
    - two dimensional object, a nested table of *perlish_util_udt* objects. *arr_perlish_from_arr_varchar2* will construct one of those for you from an *arr_arr_varchar2_udt*.
- p_skip_rows NUMBER
    - You can have the returned cursor skip one or more rows from the start of the collection.
- p_trim_rows NUMBER
    - You can have the returned cursor stop before reading the last, or last few rows of the collection.

#### Discussion

You have a two dimensional object table in PL/SQL and want a cursor that selects from it. There are a variable number 
of columns and the columns do not have names. *get_cursor_from_collections* will construct and open a cursor that
provides that resultset.

The blog post [Create a PL/SQL Cursor from a Nested Table of Nested Tables](https://lee-lindley.github.io/oracle/sql/plsql/2022/11/24/Cursor_from_Collections.html) may provide context for this.

### arr_perlish_from_arr_varchar2

Given a collection of VARCHAR2 collections, convert the two dimensional array into
an *arr_perlish_util_udt*. 

#### Parameters

- p_arr_arr ARR_ARR_VARCHAR2_UDT
    - a nested table of nested tables of VARCHAR2(4000), aka a two dimensional collection of strings object.

#### Discussion

Normally this would be a constructor, but collection
objects don't have those. We would have to build a container object. Since this is the
only method it needs, seemed prudent to stuff it into this package.

#### hash_slice

Given an associative array (hash) and and array of key values, return an array with the values
from the hash for each key in the same order as the provided key list.

#### hash_slice_assign

The provided collection (or the returned collection for Functions) has values
assigned from *p_arr_b* for the corresponding element of *p_arr_a* as the index.
Both arrays must have the same number of elements or an exception is raised.

#### cursor2hash

Given a cursor that returns two columns, both of which that should be VARCHAR2 up to 4000 chars, populate
and return an associative array with indicies from the first column and values from the second column.

#### query2hash

Creates a cursor from the query string and passes to *cursor2hash*. The package is
defined with invoker rights (AUTHID CURRENT_USER), so the caller must have privileges on any
objects used by the query.

#### indicies_of

Given an associative array (hash), returns the indicies in the order Oracle stores them
as a nested table collection.

#### values_of

Given an associative array (hash), returns the values in the order Oracle stores them
as a nested table collection.

#### pairs_of

The function variant returns a collection of VARCHAR2 collections, each of which is a pair (index, value).

The procedure variant initializes and populates the OUT parameters with the indexes and values respectively.

