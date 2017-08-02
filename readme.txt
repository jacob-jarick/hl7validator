Validation Checks

	Warnings:

	* Field exceeds length limit

	Errors

	* Ensures valid Date and Date+Time
	* AO3 - must have discharge date
	* ADT_A01 & ADT_A02 should not have PV1.45 defined



C:\hl7validator>perl hl7_validate.pl --help

hl7view tool

formats the awful hl7 pipe seperated format into human readable.

Default is to show all hl7 messages with warnings and errors.

useage: cat file | hl7view.pl

options:

        --help          this text
        --errors        only show errors
        --json          turn on json output (turns off human readable)
        --pid=PID       filter by patient ID
        --visitid=ID    filter by patient visitorid by ID
        --type=TYPE     only display messages containing TYPE (eg A03)
        --uid=UID       display HL7 message with specific UID
        --raw           display raw HL7 message
        --all           display all hl7 messages
        --pause         pause on errors
