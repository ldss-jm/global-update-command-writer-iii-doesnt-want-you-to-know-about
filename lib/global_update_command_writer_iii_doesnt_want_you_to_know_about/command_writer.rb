module GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout
  # Writes global update save files containing commands that load customized (per
  # record) payload data into each record
  #
  # @example Write save files that load custom-per-record $3 data
  #   cw = GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout::CommandWriter.new(
  #     recs: records, rectype: 'holdings',
  #     filestem: 'm583_updates', keyfield: '001'
  #   )
  #   cw.write_command do |rec|
  #     completeness = Completeness583.new(rec, completeness_constants)
  #     "|3#{completeness.m583sf3}"
  #   end
  #
  # This class is also aliased as CommandWriter (in top-level namespace)
  class CommandWriter

    # @param recs [Array<Sierra::Data::{Bib,Item,etc.}>, Array<MARC::Record>,
    #   String] the records to be updated.
    #   If a String, it must contain the file/path of a binary MARC file
    #   containing accurate/current MARC for the records.
    # @param rectype [String] record type: 'bib', 'item', 'holdings', 'authority',
    #   'resource'
    # @param filestem [String] basename for the output save files
    #   (e.g. 'm583_updates' yields save files named like 'm593_updates_001', ...)
    # @param keyfield [String] marc tag for the field where each record contains a
    #   unique key in the record set (e.g. '001')
    # @param outfield [Array<String>] the field used to hold the "final" payload
    #   data. In practice this is likely to still a temporary holding field that
    #   you will later global update into the actual field you want. So, if you
    #   ultimately want 5831_ fields, this should still be set to something like
    #   99998 fields.
    # @param temp_outfield this field is used to temporarily stage duplicated data
    #   from the keyfield.
    # @param [Hash] opts options
    # @option opts [Boolean] :recs_are_marc_objects (false)
    #   whether recs parameter is an Array of MARC::Record objects
    # @option opts [Boolean] :recs_are_marc_file (false)
    #   whether recs parameter is a String containing the name/path of a binary
    #   MARC file
    def initialize(recs:, rectype:, filestem:, keyfield:, outfield: ['999', '9', '8'], temp_outfield: ['999', '9', '9'], **opts)
      @recs = recs
      marc_to_struct if opts[:recs_are_marc_objects]
      marcfile_to_struct if opts[:recs_are_marc_file]
      @rectype = rectype
      @filestem = filestem
      @keyfield = keyfield
      @outfield = outfield
      @temp_outfield = temp_outfield
      @problems = true if keyfield_problems
      @problems = true if outfield_problems
    end

    # When passed a block that yields payload data, writes global update save
    # files containing the commands to load those payloads.
    #
    # Each save file contains:
    # - a command to duplicate the keyfield into a temp_outfield
    # - a number of commands that map specific keyfield values (in the
    #   temp_outfields) into specific payload values and change the field
    #   to an outfield
    # - a command to delete any unchanged temp_outfields
    #
    # @yield [rec] Yields each rec from @recs
    # @yieldreturn [String] payload data (e.g. "|3v.1-v.10")
    # @raise [StandardError] if the set of records has problems: record(s) already
    #   contain the fields designated as outfield/temp_outfield; record(s) do not
    #   contain exactly one keyfield; some records share keyfield values
    #
    # @example Write commands to load $3s containing the bnum for each rec
    #   cw.write_command do |rec|
    #     "|3#{rec.bnum}"
    #   end
    def write_command
      raise StandardError if @problems

      i = 1
      ofile = nil

      @recs.each do |rec|
        change_to = yield(rec)
        next unless change_to

        ofile ||= prep_outfile(i)
        change_from = rec.marc['001'].value
        command = change_dupefield_command(change_from, change_to)

        # Save files must be no larger than 10000 bytes for Sierra to completely
        # load them.
        if ofile.size + command.length + delete_dupefield_command.length > 10000
          ofile << delete_dupefield_command
          ofile.close
          i += 1
          ofile = prep_outfile(i)
        end
        ofile << command
      end

      # delete any unchanged duplicated fields
      ofile << delete_dupefield_command
      ofile.close
    end

    private

    attr_reader :recs, :rectype, :filestem, :keyfield, :outfield, :temp_outfield

    def field_group_tag
      case rectype
      when 'bib'
        'y' # misc
      when 'item'
        'x' # internal note
      when 'order', 'holdings', 'holding'
        'z' # internal note
      when 'authority'
        'n' # note
      when 'resource'
        'n' # internal note
      end
    end

    # Converts array of MARC::Record objects into structs that can serve
    # as SierraPostgresUtilities record proxies.
    def marc_to_struct

      rec_struct = Struct.new(:marc, :rnum)
      recs.map! { |rec| rec_struct.new(rec, rec['001'].value) }
    end

    # Reads binary MARC file and converts those records into structs that can
    # serve as SierraPostgresUtilities record proxies.
    def marcfile_to_struct
      require 'marc'
      @recs = MARC::Reader.new(recs).to_a
      marc_to_struct
    end

    # Each record must contain exactly one keyfield and each record must have
    # a unique keyfield value.
    def keyfield_problems
      if recs_with_no_keyfield.any?
        problems = true
        puts "records with no keyfield (#{keyfield})"
        recs_with_no_keyfield.each { |rec| puts rec.rnum }
      end
      if recs_with_multiple_keyfields.any?
        problems = true
        puts "records with multiple keyfields (#{keyfield})"
        recs_with_multiple_keyfields.each { |rec| puts rec.rnum }
      end
      if recs_with_nonunique_keyfields.any?
        problems = true
        puts "records with nonunique keyfields (#{keyfield})"
        recs_with_nonunique_keyfields.each { |rec| puts rec.rnum }
      end
      return problems if problems
    end

    def recs_with_no_keyfield
      recs.select { |rec| rec.marc.fields(keyfield).empty? }
    end

    def recs_with_multiple_keyfields
      recs.select { |rec| rec.marc.fields(keyfield).length > 1 }
    end

    def recs_with_nonunique_keyfields
      field_values = recs.group_by { |rec| rec.marc[keyfield].value }
      field_values.values.select { |r| r.length > 1 }.flatten
    end

    # Each record cannot contain instances of the fields we use as outfields
    # or temp_outfields.
    def outfield_problems
      if recs_with_outfields.any?
        problems = true
        puts "records with outfields (#{outfield.join})"
        recs_with_outfields.each { |rec| puts rec.rnum }
      end
      if recs_with_temp_outfields.any?
        problems = true
        puts "records with temp_outfields (#{temp_outfield.join})"
        recs_with_temp_outfields.each { |rec| puts rec.rnum }
      end
      return problems if problems
    end

    def recs_with_outfields
      recs.select do |rec|
        rec.marc.fields(outfield[0]).
          find { |f| f.indicator1 = outfield[1] && f.indicator2 = outfield[2] }
      end
    end

    def recs_with_temp_outfields
      recs.select do |rec|
        rec.marc.fields(temp_outfield[0]).
          find { |f| f.indicator1 = temp_outfield[1] && f.indicator2 = temp_outfield[2] }
      end
    end

    # Apparently Sierra wants these files to be in cp-1252 (or at least something
    # not utf-8). With cp-1252, Sierra correctly reads, e.g., "årg" (c13803633).
    def prep_outfile(i = 0)
      filename = [filestem, i.to_s.rjust(3, '0')].join('_')
      ofile = File.open(filename, 'w:cp1252')
      ofile << "1#{filename}\n"
      ofile << make_dupefield_command
      ofile
    end

    # A global update command to duplicate the keyfield into a temp_outfield
    # with an appropriate field group tag.
    def make_dupefield_command
      ["0O\u0001\u0001", keyfield, "\u0001"*8, field_group_tag, "\u0001",
      temp_outfield[0], "\u0001", temp_outfield[1], "\u0001", temp_outfield[2],
      "\u0001\u0001    "].join
    end

    # A global update command to delete any remaining temp_outfields
    def delete_dupefield_command
      ["\n0D\u0001\u0001", temp_outfield[0], "\u0001", temp_outfield[1], "\u0001",
      temp_outfield[2], "\u0001"*11, "    "].join
    end

    # A global update command to change a temp_outfield containing a specific
    # keyfield-value into an outfield containing specific payload data.
    def change_dupefield_command(change_from, change_to)
      ["\n0C\u0001\u0001", temp_outfield[0], "\u0001", temp_outfield[1],
      "\u0001", temp_outfield[2], "\u0001", change_from, "\u0001"*6,
      outfield[0], "\u0001", outfield[1], "\u0001", outfield[2],
      "\u0001", change_to, "\u0001    "].join
    end
  end
end

# An optional alias for GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout
CommandWriter = GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout::CommandWriter
