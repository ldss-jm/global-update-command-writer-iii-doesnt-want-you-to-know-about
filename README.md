
# GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout

Writes Sierra (III ILS) global update save files that allow customized (per record) data to be loaded into records using global update.

## What? And why?

Global update allows you to modify sets of records. It's limited in various ways; for example, the find/replace doesn't allow regular expressions.

Generally, when we want to change records in a way that can't be done through global update, our solution is to make stub marc records, and then use Data Exchange and a load profile that will add whatever fields to the overlaid record but protect any existing fields.

But you cannot load holdings records, for example, in that manner. So we used this when we wanted to add 583s (including essentially a concatenation of the 866/867/868 fields) to holdings records.

This is probably not a widely useful tool. And when using Data Exchange is an option, that is likely preferable. But this was really pretty useful.

Once.

## Installation

```bash
bundle install
bundle exec rake install
```

## Requirements

This relies on there being a MARC field that operates as a `keyfield`:

- that each record has exactly one of
- and where each record's field value is unique (in the set of records being modified).

(The code will check that these conditions are true for the `keyfield` you specify.)

Apart from that, it assumes you're using the [sierra_postgres_utilities gem](https://github.com/UNC-Libraries/sierra-postgres-utilities). However if you have a MARC file containing accurate MARC for each of the records, that will work too (i.e. it's not tested but it might work) -- in which case it requires only the [marc gem](https://github.com/ruby-marc/ruby-marc/).

## Usage

```ruby
require 'global_update_command_writer_iii_doesnt_want_you_to_know_about'

records = Sierra::Data::CreateList.get(76).records

# Create a CommandWriter
cw = GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout::CommandWriter.new(
  recs: records, rectype: 'holdings',
  filestem: 'm583_updates', keyfield: '001'
)

# Use a block to write global update save files that will load the payload data.
# Here, we're loading each record's cnum (e.g. c1288266a) into a 999$3 as an
# example, but the payload can be anything.
cw.write_command do |rec|
  "|3#{rec.rnum}"
end

# You can use a MARC file rather than a database connection. (You can also
# initialize using CommandWriter, if you prefer.)
cw = CommandWriter.new(recs: 'records.mrc', rectype: 'holdings',
                       filestem: 'm583_updates', keyfield: '001',
                       recs_are_marc_file: true)
```

`rectype` is one of: `bib`, `item`, `holdings`, `authority`, `resource`

## Notes

The resulting global update save files result in the payload data being written
to records in a `99998` field with a field group tag like `note` / `internal note` / `misc` (depending on the record type). You would then update the `99998` fields to whatever you want them to be.

Also, it seems that global update save files cannot be larger than 10000 bytes. Any commands not fully contained within the first 10000 bytes aren't loaded into Sierra. So this breaks the save files into segments not larger than 10000 bytes.

Because of this size limitation, it may be advantageous to use this method to load the minimal amount of data needed, and use normal methods for any data you can. For example, we wanted to write 583 fields with an initial $3 containing a holdings statement. The holdings statement varied per record so we needed to use tis method. The rest of the 583 was longish and static -- it did not vary from record to record. So, we avoided including the long, static data in this method because it meant we would load/process fewer save files. After we process the save files we went back and added the static data to the fields in a standard global update.
