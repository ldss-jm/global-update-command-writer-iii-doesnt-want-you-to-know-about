require 'spec_helper'

module GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout
  RSpec.describe CommandWriter do
    let(:bib) do
      m = MARC::Record.new
      m << MARC::ControlField.new('001', 'unique_value')
      m
    end

    let(:cw) do
      CommandWriter.new(recs: [bib], rectype: 'bib',
                        filestem: 'test', keyfield: '001',
                        recs_are_marc_objects: true)
    end

    describe '#make_dupefield_command' do
      it 'outputs a Sierra global update "copy" command' do
        expect(cw.send(:make_dupefield_command)).to eq(
          "0O\u0001\u0001001\u0001\u0001\u0001\u0001\u0001\u0001\u0001\u0001y\u0001999\u00019\u00019\u0001\u0001    "
        )
      end
    end

    describe '#delete_dupefield_command' do
      it 'outputs a Sierra global update "delete" command' do
        expect(cw.send(:delete_dupefield_command)).to eq(
          "\n0D\u0001\u0001999\u00019\u00019\u0001\u0001\u0001\u0001\u0001\u0001\u0001\u0001\u0001\u0001\u0001    "
        )
      end
    end

    describe '#change_dupefield_command' do
      it 'outputs a Sierra global update "change" command' do
        expect(cw.send(:change_dupefield_command, 'foo', 'bar')).to eq(
          "\n0C\u0001\u0001999\u00019\u00019\u0001foo\u0001\u0001\u0001\u0001\u0001\u0001999\u00019\u00018\u0001bar\u0001    "
        )
      end
    end
  end
end

RSpec.describe CommandWriter do
  it 'is unwieldy and so has CommandWriter as a top-level namespace alias' do
    bib = MARC::Record.new
    bib << MARC::ControlField.new('001', 'unique_value')
    cw = CommandWriter.new(recs: [bib], rectype: 'bib',
                           filestem: 'test', keyfield: '001',
                           recs_are_marc_objects: true)
    expect(cw).to(
      be_a(GlobalUpdateCommandWriterIIIDoesntWantYouToKnowAbout::CommandWriter)
    )
  end
end
