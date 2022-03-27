# to_zoned_decimal

Format a number into a mainframe style Zoned Decimal. The use case is producing a 
fixed width text file to send to a mainframe. For example:

Number: 6.80    
Format: S9(7)V99   
Arguments: p_number=>6.8, p_digits_before_decimal=>7, p_digits_after_decimal=>2   
Result: '00000068{'    

```sql
FUNCTION to_zoned_decimal(
    p_number                    NUMBER
    ,p_digits_before_decimal    BINARY_INTEGER          -- characteristic S9(7)V99 then 7
    ,p_digits_after_decimal     BINARY_INTEGER := NULL  -- mantissa       S9(7)V99 then 2
) RETURN VARCHAR2 DETERMINISTIC
```

Converting from zoned decimal string to number is a task you would perform with sqlldr or external table.
The sqlldr driver has a conversion type for zoned decimal ( for S9(7)V99 use ZONED(9,2) ).

