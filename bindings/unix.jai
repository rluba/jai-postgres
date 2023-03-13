//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



InvalidOid :: cast(Oid) 0;

PG_COPYRES_ATTRS :: 0x01;
PG_COPYRES_TUPLES :: 0x02;
PG_COPYRES_EVENTS :: 0x04;
PG_COPYRES_NOTICEHOOKS :: 0x08;

PQnoPasswordSupplied :: "fe_sendauth: no password supplied\n";

/*
* Object ID is a fundamental type in Postgres.
*/
Oid :: u32;

/* Define a signed 64-bit integer type for use in client API declarations. */
pg_int64 :: s64;

/*
* Although it is okay to add to these lists, values which become unused
* should never be removed, nor should constants be redefined - that would
* break compatibility with existing code.
*/
ConnStatusType :: enum u32 {
    CONNECTION_OK                :: 0;
    CONNECTION_BAD               :: 1;

    CONNECTION_STARTED           :: 2;
    CONNECTION_MADE              :: 3;
    CONNECTION_AWAITING_RESPONSE :: 4;

    CONNECTION_AUTH_OK           :: 5;

    CONNECTION_SETENV            :: 6;
    CONNECTION_SSL_STARTUP       :: 7;
    CONNECTION_NEEDED            :: 8;
    CONNECTION_CHECK_WRITABLE    :: 9;

    CONNECTION_CONSUME           :: 10;
}

PostgresPollingStatusType :: enum u32 {
    PGRES_POLLING_FAILED  :: 0;
    PGRES_POLLING_READING :: 1;
    PGRES_POLLING_WRITING :: 2;
    PGRES_POLLING_OK      :: 3;
    PGRES_POLLING_ACTIVE  :: 4;
}

ExecStatusType :: enum u32 {
    PGRES_EMPTY_QUERY    :: 0;
    PGRES_COMMAND_OK     :: 1;

    PGRES_TUPLES_OK      :: 2;

    PGRES_COPY_OUT       :: 3;
    PGRES_COPY_IN        :: 4;
    PGRES_BAD_RESPONSE   :: 5;

    PGRES_NONFATAL_ERROR :: 6;
    PGRES_FATAL_ERROR    :: 7;
    PGRES_COPY_BOTH      :: 8;
    PGRES_SINGLE_TUPLE   :: 9;
}

PGTransactionStatusType :: enum u32 {
    PQTRANS_IDLE    :: 0;
    PQTRANS_ACTIVE  :: 1;
    PQTRANS_INTRANS :: 2;
    PQTRANS_INERROR :: 3;
    PQTRANS_UNKNOWN :: 4;
}

PGVerbosity :: enum u32 {
    PQERRORS_TERSE   :: 0;
    PQERRORS_DEFAULT :: 1;
    PQERRORS_VERBOSE :: 2;
}

PGContextVisibility :: enum u32 {
    PQSHOW_CONTEXT_NEVER  :: 0;
    PQSHOW_CONTEXT_ERRORS :: 1;
    PQSHOW_CONTEXT_ALWAYS :: 2;
}

/*
* PGPing - The ordering of this enum should not be altered because the
* values are exposed externally via pg_isready.
*/
PGPing :: enum u32 {
    PQPING_OK          :: 0;
    PQPING_REJECT      :: 1;
    PQPING_NO_RESPONSE :: 2;
    PQPING_NO_ATTEMPT  :: 3;
}

pg_conn :: struct {}
/* PGconn encapsulates a connection to the backend.
* The contents of this struct are not supposed to be known to applications.
*/
PGconn :: pg_conn;

pg_result :: struct {}
/* PGresult encapsulates the result of a query (or more precisely, of a single
* SQL command --- a query string given to PQsendQuery can contain multiple
* commands and thus return multiple PGresult objects).
* The contents of this struct are not supposed to be known to applications.
*/
PGresult :: pg_result;

pg_cancel :: struct {}
/* PGcancel encapsulates the information needed to cancel a running
* query on an existing connection.
* The contents of this struct are not supposed to be known to applications.
*/
PGcancel :: pg_cancel;

/* PGnotify represents the occurrence of a NOTIFY message.
* Ideally this would be an opaque typedef, but it's so simple that it's
* unlikely to change.
* NOTE: in Postgres 6.4 and later, the be_pid is the notifying backend's,
* whereas in earlier versions it was always your own backend's PID.
*/
pgNotify :: struct {
    relname: *u8; /* notification condition name */
    be_pid:  s32; /* process ID of notifying server process */
    extra:   *u8; /* notification parameter */

    next:    *pgNotify; /* list link */
}

/* PGnotify represents the occurrence of a NOTIFY message.
* Ideally this would be an opaque typedef, but it's so simple that it's
* unlikely to change.
* NOTE: in Postgres 6.4 and later, the be_pid is the notifying backend's,
* whereas in earlier versions it was always your own backend's PID.
*/
PGnotify :: pgNotify;

/* Function types for notice-handling callbacks */
PQnoticeReceiver :: #type (arg: *void, res: *PGresult) -> void #c_call;
PQnoticeProcessor :: #type (arg: *void, message: *u8) -> void #c_call;

/* Print options for PQprint() */
pqbool :: u8;

_PQprintOpt :: struct {
    header:    pqbool; /* print output field headings and row count */
    align:     pqbool; /* fill align the fields */
    standard:  pqbool; /* old brain dead format */
    html3:     pqbool; /* output html tables */
    expanded:  pqbool; /* expand tables */
    pager:     pqbool; /* use pager for output if needed */
    fieldSep:  *u8; /* field separator */
    tableOpt:  *u8; /* insert to HTML <table ...> */
    caption:   *u8; /* HTML <caption> */
    /* null terminated array of replacement field
    * names */
    fieldName: **u8;
}

PQprintOpt :: _PQprintOpt;

/* ----------------
* Structure for the conninfo parameter definitions returned by PQconndefaults
* or PQconninfoParse.
*
* All fields except "val" point at static strings which must not be altered.
* "val" is either NULL or a malloc'd current-value string.  PQconninfoFree()
* will release both the val strings and the PQconninfoOption array itself.
* ----------------
*/
_PQconninfoOption :: struct {
    keyword:  *u8; /* The keyword of the option			*/
    envvar:   *u8; /* Fallback environment variable name	*/
    compiled: *u8; /* Fallback compiled in default value	*/
    val:      *u8; /* Option's current value, or NULL		 */
    label:    *u8; /* Label for field in connect dialog	*/
    /* Indicates how to display this field in a
    * connect dialog. Values are: "" Display
    * entered value as is "*" Password field -
    * hide value "D"  Debug option - don't show
    * by default */
    dispchar: *u8;

    dispsize: s32; /* Field size in characters for dialog	*/
}

/* ----------------
* Structure for the conninfo parameter definitions returned by PQconndefaults
* or PQconninfoParse.
*
* All fields except "val" point at static strings which must not be altered.
* "val" is either NULL or a malloc'd current-value string.  PQconninfoFree()
* will release both the val strings and the PQconninfoOption array itself.
* ----------------
*/
PQconninfoOption :: _PQconninfoOption;

/* ----------------
* PQArgBlock -- structure for PQfn() arguments
* ----------------
*/
PQArgBlock :: struct {
    len:   s32;
    isint: s32;
    u:     union {
        ptr:     *s32; /* can't use void (dec compiler barfs)	 */
        integer: s32;
    };
}

/* ----------------
* PGresAttDesc -- Data about a single attribute (column) of a query result
* ----------------
*/
pgresAttDesc :: struct {
    name:      *u8; /* column name */
    tableid:   Oid; /* source table, if known */
    columnid:  s32; /* source column, if known */
    format:    s32; /* format code for value (text/binary) */
    typid:     Oid; /* type id */
    typlen:    s32; /* type size */
    atttypmod: s32; /* type-specific modifier info */
}

/* ----------------
* PGresAttDesc -- Data about a single attribute (column) of a query result
* ----------------
*/
PGresAttDesc :: pgresAttDesc;

/* make a new client connection to the backend */
/* Asynchronous (non-blocking) */
PQconnectStart :: (conninfo: *u8) -> *PGconn #foreign libpq;
PQconnectStartParams :: (keywords: **u8, values: **u8, expand_dbname: s32) -> *PGconn #foreign libpq;

PQconnectPoll :: (conn: *PGconn) -> PostgresPollingStatusType #foreign libpq;

/* Synchronous (blocking) */
PQconnectdb :: (conninfo: *u8) -> *PGconn #foreign libpq;
PQconnectdbParams :: (keywords: **u8, values: **u8, expand_dbname: s32) -> *PGconn #foreign libpq;

PQsetdbLogin :: (pghost: *u8, pgport: *u8, pgoptions: *u8, pgtty: *u8, dbName: *u8, login: *u8, pwd: *u8) -> *PGconn #foreign libpq;

/* close the current connection and free the PGconn data structure */
PQfinish :: (conn: *PGconn) -> void #foreign libpq;

/* get info about connection options known to PQconnectdb */
PQconndefaults :: () -> *PQconninfoOption #foreign libpq;

/* parse connection options in same way as PQconnectdb */
PQconninfoParse :: (conninfo: *u8, errmsg: **u8) -> *PQconninfoOption #foreign libpq;

/* return the connection options used by a live connection */
PQconninfo :: (conn: *PGconn) -> *PQconninfoOption #foreign libpq;

/* free the data structure returned by PQconndefaults() or PQconninfoParse() */
PQconninfoFree :: (connOptions: *PQconninfoOption) -> void #foreign libpq;

/*
* close the current connection and restablish a new one with the same
* parameters
*/
/* Asynchronous (non-blocking) */
PQresetStart :: (conn: *PGconn) -> s32 #foreign libpq;
PQresetPoll :: (conn: *PGconn) -> PostgresPollingStatusType #foreign libpq;

/* Synchronous (blocking) */
PQreset :: (conn: *PGconn) -> void #foreign libpq;

/* request a cancel structure */
PQgetCancel :: (conn: *PGconn) -> *PGcancel #foreign libpq;

/* free a cancel structure */
PQfreeCancel :: (cancel: *PGcancel) -> void #foreign libpq;

/* issue a cancel request */
PQcancel :: (cancel: *PGcancel, errbuf: *u8, errbufsize: s32) -> s32 #foreign libpq;

/* backwards compatible version of PQcancel; not thread-safe */
PQrequestCancel :: (conn: *PGconn) -> s32 #foreign libpq;

/* Accessor functions for PGconn objects */
PQdb :: (conn: *PGconn) -> *u8 #foreign libpq;
PQuser :: (conn: *PGconn) -> *u8 #foreign libpq;
PQpass :: (conn: *PGconn) -> *u8 #foreign libpq;
PQhost :: (conn: *PGconn) -> *u8 #foreign libpq;
PQport :: (conn: *PGconn) -> *u8 #foreign libpq;
PQtty :: (conn: *PGconn) -> *u8 #foreign libpq;
PQoptions :: (conn: *PGconn) -> *u8 #foreign libpq;
PQstatus :: (conn: *PGconn) -> ConnStatusType #foreign libpq;
PQtransactionStatus :: (conn: *PGconn) -> PGTransactionStatusType #foreign libpq;
PQparameterStatus :: (conn: *PGconn, paramName: *u8) -> *u8 #foreign libpq;

PQprotocolVersion :: (conn: *PGconn) -> s32 #foreign libpq;
PQserverVersion :: (conn: *PGconn) -> s32 #foreign libpq;
PQerrorMessage :: (conn: *PGconn) -> *u8 #foreign libpq;
PQsocket :: (conn: *PGconn) -> s32 #foreign libpq;
PQbackendPID :: (conn: *PGconn) -> s32 #foreign libpq;
PQconnectionNeedsPassword :: (conn: *PGconn) -> s32 #foreign libpq;
PQconnectionUsedPassword :: (conn: *PGconn) -> s32 #foreign libpq;
PQclientEncoding :: (conn: *PGconn) -> s32 #foreign libpq;
PQsetClientEncoding :: (conn: *PGconn, encoding: *u8) -> s32 #foreign libpq;

/* SSL information functions */
PQsslInUse :: (conn: *PGconn) -> s32 #foreign libpq;
PQsslStruct :: (conn: *PGconn, struct_name: *u8) -> *void #foreign libpq;
PQsslAttribute :: (conn: *PGconn, attribute_name: *u8) -> *u8 #foreign libpq;
PQsslAttributeNames :: (conn: *PGconn) -> **u8 #foreign libpq;

/* Get the OpenSSL structure associated with a connection. Returns NULL for
* unencrypted connections or if any other TLS library is in use. */
PQgetssl :: (conn: *PGconn) -> *void #foreign libpq;

/* Tell libpq whether it needs to initialize OpenSSL */
PQinitSSL :: (do_init: s32) -> void #foreign libpq;

/* More detailed way to tell libpq whether it needs to initialize OpenSSL */
PQinitOpenSSL :: (do_ssl: s32, do_crypto: s32) -> void #foreign libpq;

/* Set verbosity for PQerrorMessage and PQresultErrorMessage */
PQsetErrorVerbosity :: (conn: *PGconn, verbosity: PGVerbosity) -> PGVerbosity #foreign libpq;

/* Set CONTEXT visibility for PQerrorMessage and PQresultErrorMessage */
PQsetErrorContextVisibility :: (conn: *PGconn, show_context: PGContextVisibility) -> PGContextVisibility #foreign libpq;

/* Enable/disable tracing */
PQtrace :: (conn: *PGconn, debug_port: *FILE) -> void #foreign libpq;
PQuntrace :: (conn: *PGconn) -> void #foreign libpq;

/* Override default notice handling routines */
PQsetNoticeReceiver :: (conn: *PGconn, proc: PQnoticeReceiver, arg: *void) -> PQnoticeReceiver #foreign libpq;

PQsetNoticeProcessor :: (conn: *PGconn, proc: PQnoticeProcessor, arg: *void) -> PQnoticeProcessor #foreign libpq;

/*
*	   Used to set callback that prevents concurrent access to
*	   non-thread safe functions that libpq needs.
*	   The default implementation uses a libpq internal mutex.
*	   Only required for multithreaded apps that use kerberos
*	   both within their app and for postgresql connections.
*/
pgthreadlock_t :: #type (acquire: s32) -> void #c_call;

PQregisterThreadLock :: (newhandler: pgthreadlock_t) -> pgthreadlock_t #foreign libpq;

/* Simple synchronous query */
PQexec :: (conn: *PGconn, query: *u8) -> *PGresult #foreign libpq;
PQexecParams :: (conn: *PGconn, command: *u8, nParams: s32, paramTypes: *Oid, paramValues: **u8, paramLengths: *s32, paramFormats: *s32, resultFormat: s32) -> *PGresult #foreign libpq;

PQprepare :: (conn: *PGconn, stmtName: *u8, query: *u8, nParams: s32, paramTypes: *Oid) -> *PGresult #foreign libpq;

PQexecPrepared :: (conn: *PGconn, stmtName: *u8, nParams: s32, paramValues: **u8, paramLengths: *s32, paramFormats: *s32, resultFormat: s32) -> *PGresult #foreign libpq;

/* Interface for multiple-result or asynchronous queries */
PQsendQuery :: (conn: *PGconn, query: *u8) -> s32 #foreign libpq;
PQsendQueryParams :: (conn: *PGconn, command: *u8, nParams: s32, paramTypes: *Oid, paramValues: **u8, paramLengths: *s32, paramFormats: *s32, resultFormat: s32) -> s32 #foreign libpq;

PQsendPrepare :: (conn: *PGconn, stmtName: *u8, query: *u8, nParams: s32, paramTypes: *Oid) -> s32 #foreign libpq;

PQsendQueryPrepared :: (conn: *PGconn, stmtName: *u8, nParams: s32, paramValues: **u8, paramLengths: *s32, paramFormats: *s32, resultFormat: s32) -> s32 #foreign libpq;

PQsetSingleRowMode :: (conn: *PGconn) -> s32 #foreign libpq;
PQgetResult :: (conn: *PGconn) -> *PGresult #foreign libpq;

/* Routines for managing an asynchronous query */
PQisBusy :: (conn: *PGconn) -> s32 #foreign libpq;
PQconsumeInput :: (conn: *PGconn) -> s32 #foreign libpq;

/* LISTEN/NOTIFY support */
PQnotifies :: (conn: *PGconn) -> *PGnotify #foreign libpq;

/* Routines for copy in/out */
PQputCopyData :: (conn: *PGconn, buffer: *u8, nbytes: s32) -> s32 #foreign libpq;
PQputCopyEnd :: (conn: *PGconn, errormsg: *u8) -> s32 #foreign libpq;
PQgetCopyData :: (conn: *PGconn, buffer: **u8, async: s32) -> s32 #foreign libpq;

/* Deprecated routines for copy in/out */
PQgetline :: (conn: *PGconn, _string: *u8, length: s32) -> s32 #foreign libpq;
PQputline :: (conn: *PGconn, _string: *u8) -> s32 #foreign libpq;
PQgetlineAsync :: (conn: *PGconn, buffer: *u8, bufsize: s32) -> s32 #foreign libpq;
PQputnbytes :: (conn: *PGconn, buffer: *u8, nbytes: s32) -> s32 #foreign libpq;
PQendcopy :: (conn: *PGconn) -> s32 #foreign libpq;

/* Set blocking/nonblocking connection to the backend */
PQsetnonblocking :: (conn: *PGconn, arg: s32) -> s32 #foreign libpq;
PQisnonblocking :: (conn: *PGconn) -> s32 #foreign libpq;
PQisthreadsafe :: () -> s32 #foreign libpq;
PQping :: (conninfo: *u8) -> PGPing #foreign libpq;
PQpingParams :: (keywords: **u8, values: **u8, expand_dbname: s32) -> PGPing #foreign libpq;

/* Force the write buffer to be written (or at least try) */
PQflush :: (conn: *PGconn) -> s32 #foreign libpq;

/*
* "Fast path" interface --- not really recommended for application
* use
*/
PQfn :: (conn: *PGconn, fnid: s32, result_buf: *s32, result_len: *s32, result_is_int: s32, args: *PQArgBlock, nargs: s32) -> *PGresult #foreign libpq;

/* Accessor functions for PGresult objects */
PQresultStatus :: (res: *PGresult) -> ExecStatusType #foreign libpq;
PQresStatus :: (status: ExecStatusType) -> *u8 #foreign libpq;
PQresultErrorMessage :: (res: *PGresult) -> *u8 #foreign libpq;
PQresultVerboseErrorMessage :: (res: *PGresult, verbosity: PGVerbosity, show_context: PGContextVisibility) -> *u8 #foreign libpq;

PQresultErrorField :: (res: *PGresult, fieldcode: s32) -> *u8 #foreign libpq;
PQntuples :: (res: *PGresult) -> s32 #foreign libpq;
PQnfields :: (res: *PGresult) -> s32 #foreign libpq;
PQbinaryTuples :: (res: *PGresult) -> s32 #foreign libpq;
PQfname :: (res: *PGresult, field_num: s32) -> *u8 #foreign libpq;
PQfnumber :: (res: *PGresult, field_name: *u8) -> s32 #foreign libpq;
PQftable :: (res: *PGresult, field_num: s32) -> Oid #foreign libpq;
PQftablecol :: (res: *PGresult, field_num: s32) -> s32 #foreign libpq;
PQfformat :: (res: *PGresult, field_num: s32) -> s32 #foreign libpq;
PQftype :: (res: *PGresult, field_num: s32) -> Oid #foreign libpq;
PQfsize :: (res: *PGresult, field_num: s32) -> s32 #foreign libpq;
PQfmod :: (res: *PGresult, field_num: s32) -> s32 #foreign libpq;
PQcmdStatus :: (res: *PGresult) -> *u8 #foreign libpq;
PQoidStatus :: (res: *PGresult) -> *u8 #foreign libpq;
PQoidValue :: (res: *PGresult) -> Oid #foreign libpq;
PQcmdTuples :: (res: *PGresult) -> *u8 #foreign libpq;
PQgetvalue :: (res: *PGresult, tup_num: s32, field_num: s32) -> *u8 #foreign libpq;
PQgetlength :: (res: *PGresult, tup_num: s32, field_num: s32) -> s32 #foreign libpq;
PQgetisnull :: (res: *PGresult, tup_num: s32, field_num: s32) -> s32 #foreign libpq;
PQnparams :: (res: *PGresult) -> s32 #foreign libpq;
PQparamtype :: (res: *PGresult, param_num: s32) -> Oid #foreign libpq;

/* Describe prepared statements and portals */
PQdescribePrepared :: (conn: *PGconn, stmt: *u8) -> *PGresult #foreign libpq;
PQdescribePortal :: (conn: *PGconn, portal: *u8) -> *PGresult #foreign libpq;
PQsendDescribePrepared :: (conn: *PGconn, stmt: *u8) -> s32 #foreign libpq;
PQsendDescribePortal :: (conn: *PGconn, portal: *u8) -> s32 #foreign libpq;

/* Delete a PGresult */
PQclear :: (res: *PGresult) -> void #foreign libpq;

/* For freeing other alloc'd results, such as PGnotify structs */
PQfreemem :: (ptr: *void) -> void #foreign libpq;

/* Create and manipulate PGresults */
PQmakeEmptyPGresult :: (conn: *PGconn, status: ExecStatusType) -> *PGresult #foreign libpq;
PQcopyResult :: (src: *PGresult, flags: s32) -> *PGresult #foreign libpq;
PQsetResultAttrs :: (res: *PGresult, numAttributes: s32, attDescs: *PGresAttDesc) -> s32 #foreign libpq;
PQresultAlloc :: (res: *PGresult, nBytes: size_t) -> *void #foreign libpq;
PQsetvalue :: (res: *PGresult, tup_num: s32, field_num: s32, value: *u8, len: s32) -> s32 #foreign libpq;

/* Quoting strings before inclusion in queries. */
PQescapeStringConn :: (conn: *PGconn, to: *u8, from: *u8, length: size_t, error: *s32) -> size_t #foreign libpq;

PQescapeLiteral :: (conn: *PGconn, str: *u8, len: size_t) -> *u8 #foreign libpq;
PQescapeIdentifier :: (conn: *PGconn, str: *u8, len: size_t) -> *u8 #foreign libpq;
PQescapeByteaConn :: (conn: *PGconn, from: *u8, from_length: size_t, to_length: *size_t) -> *u8 #foreign libpq;

PQunescapeBytea :: (strtext: *u8, retbuflen: *size_t) -> *u8 #foreign libpq;

/* These forms are deprecated! */
PQescapeString :: (to: *u8, from: *u8, length: size_t) -> size_t #foreign libpq;
PQescapeBytea :: (from: *u8, from_length: size_t, to_length: *size_t) -> *u8 #foreign libpq;

/* === in fe-print.c === */
PQprint :: (fout: *FILE, res: *PGresult, ps: *PQprintOpt) -> void #foreign libpq;

/*
* really old printing routines
*/
PQdisplayTuples :: (res: *PGresult, fp: *FILE, fillAlign: s32, fieldSep: *u8, printHeader: s32, quiet: s32) -> void #foreign libpq;

PQprintTuples :: (res: *PGresult, fout: *FILE, printAttName: s32, terseOutput: s32, width: s32) -> void #foreign libpq;

/* Large-object access routines */
lo_open :: (conn: *PGconn, lobjId: Oid, mode: s32) -> s32 #foreign libpq;
lo_close :: (conn: *PGconn, fd: s32) -> s32 #foreign libpq;
lo_read :: (conn: *PGconn, fd: s32, buf: *u8, len: size_t) -> s32 #foreign libpq;
lo_write :: (conn: *PGconn, fd: s32, buf: *u8, len: size_t) -> s32 #foreign libpq;
lo_lseek :: (conn: *PGconn, fd: s32, offset: s32, whence: s32) -> s32 #foreign libpq;
lo_lseek64 :: (conn: *PGconn, fd: s32, offset: pg_int64, whence: s32) -> pg_int64 #foreign libpq;
lo_creat :: (conn: *PGconn, mode: s32) -> Oid #foreign libpq;
lo_create :: (conn: *PGconn, lobjId: Oid) -> Oid #foreign libpq;
lo_tell :: (conn: *PGconn, fd: s32) -> s32 #foreign libpq;
lo_tell64 :: (conn: *PGconn, fd: s32) -> pg_int64 #foreign libpq;
lo_truncate :: (conn: *PGconn, fd: s32, len: size_t) -> s32 #foreign libpq;
lo_truncate64 :: (conn: *PGconn, fd: s32, len: pg_int64) -> s32 #foreign libpq;
lo_unlink :: (conn: *PGconn, lobjId: Oid) -> s32 #foreign libpq;
lo_import :: (conn: *PGconn, filename: *u8) -> Oid #foreign libpq;
lo_import_with_oid :: (conn: *PGconn, filename: *u8, lobjId: Oid) -> Oid #foreign libpq;
lo_export :: (conn: *PGconn, lobjId: Oid, filename: *u8) -> s32 #foreign libpq;

/* Get the version of the libpq library in use */
PQlibVersion :: () -> s32 #foreign libpq;

/* Determine length of multibyte encoded char at *s */
PQmblen :: (s: *u8, encoding: s32) -> s32 #foreign libpq;

/* Determine display length of multibyte encoded char at *s */
PQdsplen :: (s: *u8, encoding: s32) -> s32 #foreign libpq;

/* Get encoding id from environment variable PGCLIENTENCODING */
PQenv2encoding :: () -> s32 #foreign libpq;

/* === in fe-auth.c === */
PQencryptPassword :: (passwd: *u8, user: *u8) -> *u8 #foreign libpq;
PQencryptPasswordConn :: (conn: *PGconn, passwd: *u8, user: *u8, algorithm: *u8) -> *u8 #foreign libpq;

/* === in encnames.c === */
pg_char_to_encoding :: (name: *u8) -> s32 #foreign libpq;
pg_encoding_to_char :: (encoding: s32) -> *u8 #foreign libpq;
pg_valid_server_encoding_id :: (encoding: s32) -> s32 #foreign libpq;

#scope_file


libpq :: #system_library "libpq";

