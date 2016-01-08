/**
 *
 */
module xbase;

import std.conv, std.stream, std.string;

class xBaseUnsupportedFormatException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}

///
enum xBaseDataType : char
{
	Binary = 'B',
	Character = 'C',
	Date = 'D',
	Numeric = 'N',
	Logical = 'L',
	Memo = 'M',
	Timestamp = '@',
	Long = 'l',
	Autoincrement = '+',
	Float = 'F',
	Double = 'O',
	OLE = 'G'
}

/**
 * The header structure begins every xBase database.
 */
align(1) struct xBaseHeader
{
	ubyte versionNumber; // 0
	ubyte[3] modifiedDate; // 1 	YYMMDD
	uint numRecords; // 4
	ushort headerLength; // 8
	ushort recordLength; // 10

	ubyte[2] reserved1; // 12
	ubyte incompleteTransactionFlag; // 14
	ubyte encryptionFlag; // 15
	uint freeRecordThread; // 16

	ubyte[8] reserved2; // 20-27
	ubyte mdxFlag; // 28
	ubyte languageDriver; // 29
	ubyte[2] reserved3; // 30-31
}

static assert(xBaseHeader.sizeof == 32);

/**
 * Field descriptors specify the columns in the database.
 */
align(1) struct xBaseFieldDescriptor
{
	char[11] name; // 0-10
	xBaseDataType type; // 11
	uint dataAddress; // 12-15
	ubyte length; // 16
	ubyte decimalCount; // 17
	ubyte[2] reserved1; // 18-19
	ubyte workAreaID; // 20
	ubyte[2] reserved2; // 21-22
	ubyte setFieldsFlag; // 23
	ubyte[7] reserved3; // 24-30
	ubyte indexFlag; // 31

	/**
     * Ensures that a value will fit the field, padding or truncating when
     *  necessary.
     */
	string formatValue(string v)
	{
		if (v.length > length)
			return v[0 .. this.length]; // too long, truncate

		if (v.length < length)
			return v.leftJustify(length); // too short, pad

		return v;
	}
}

static assert(xBaseFieldDescriptor.sizeof == 32);

/**
 *
 */
struct xBaseRow
{
	char _deleteFlag;
	string[] values;

	@property bool isDeleted()
	{
		return _deleteFlag == '*';
	}
}

/**
 *
 */
struct xBaseDatabase
{

	xBaseHeader header;
	xBaseFieldDescriptor[] columns;
	xBaseRow[] rows;

	/**
     * Read an xBaseDatabase from $(D stream).
-----------------------------------------
auto data = xBaseDatabase.read(new File("myfile.dbf"));
-----------------------------------------
     */
	static xBaseDatabase read(InputStream stream)
	{
		xBaseDatabase ret;

		// Read the header in
		stream.readExact(&ret.header, ret.header.sizeof);

		// Determine the number of columns (length of field descriptor array)
		ret.columns.length = cast(ubyte)((ret.header.headerLength - 33) / 32);

		// Read the field descriptor array
		foreach (ref col; ret.columns)
			stream.readExact(&col, col.sizeof);

		// Ensure that the terminator byte follows
		if (stream.getc() != '\r')
			throw new xBaseUnsupportedFormatException(
				"Expected termination of field descriptor array");

		// Read the records
		ret.rows = new xBaseRow[](ret.header.numRecords);
		foreach (row; ret.rows)
		{
			// Each row begins with a flag which indicates whether the record has
			//  been deleted or is still valid.
			stream.read(row._deleteFlag);

			// Read in the data for each field in the row
			row.values = new string[](ret.columns.length);
			foreach (column_index, val; row.values)
			{
				val.length = ret.columns[column_index].length;
				stream.readExact(cast(void*) val.ptr, val.length);
			}
		}

		// All done
		return ret;
	}

	/**
     * Writes this database to $(D stream).
     */
	void write(OutputStream stream)
	{
		assert(header.numRecords == rows.length);

		header.headerLength = cast(ushort)(
			header.sizeof + (columns.length * xBaseFieldDescriptor.sizeof) + 1 /* terminator */ );
		header.recordLength = 1;
		foreach (col; columns)
			header.recordLength += col.length;

		stream.writeExact(&header, header.sizeof);

		// write the field descriptor array
		foreach (col; columns)
			stream.writeExact(&col, col.sizeof);

		stream.write('\r'); // terminate the array

		// write the records
		foreach (row; rows)
		{
			stream.write(row._deleteFlag);
			foreach (c, field; row.values)
			{
				assert(columns[c].length <= field.length);
				stream.writeExact(field.ptr, columns[c].length);
			}
		}

		stream.write(cast(ubyte) 26); // 1Ah
	}

}
