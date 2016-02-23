import std.stdio, std.stream, std.string;
import xbase;

void main(string[] args)
{
    // Read each file passed in
    foreach (filepath; args[1 .. $])
    {
        auto db = xBaseDatabase.read(new std.stream.File(filepath));

        foreach (r; db.rows)
        {
            foreach (c; r.values)
            {
                std.stdio.writef("%s|", c.strip);
            }
            std.stdio.writeln;
        }
    }
}
