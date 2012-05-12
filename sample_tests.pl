my $uri = 'http://nodegroups/api/v2/w/create_nodegroup.php';

$TESTS = [

{
	'description' => 'create_nodegroup.php',
	'uri' => $uri,
	'request' => [
		{
			'json' => {
				'name' => $UNIQUE,
			},
		},
	],
	'response' => [
		{
			'body' => {
				'status' => 200,
				'details' => superhashof({
					'name' => $UNIQUE,
				}),
			},
		}
	],
},

];
