################################################################################

sub setup_page_content {

	my ($page) = @_;

	$_REQUEST {__allow_check___query} = 1;
	delete $_REQUEST {__the_table};

	eval { $_REQUEST {__page_content} = $page -> {content} = call_for_role (($_REQUEST {id} ? 'get_item_of_' : 'select_') . $page -> {type})};

	$_REQUEST {__allow_check___query} = 0;

	$@ and return $_REQUEST {error} = $@;

	$_USER -> {id} and !$_REQUEST {__only_menu} and $_REQUEST {__edit_query} or return;

	my $is_dump = delete $_REQUEST {__dump};

	setup_skin ();

	$_REQUEST {__allow_check___query} = 1;

	call_for_role (($_REQUEST {id} ? 'draw_item_of_' : 'draw_') . $page -> {type}, $page -> {content});

	$_REQUEST {__allow_check___query} = 0;

	$_REQUEST {__dump} = $is_dump;

	$_REQUEST {id___query} ||= sql_select_id (

		$conf -> {systables} -> {__queries} => {
			id_user     => $_USER -> {id},
			type        => $_REQUEST {type},
			label       => '',
			order_context		=> $_REQUEST {__order_context} || '',
		}, ['id_user', 'type', 'label', 'order_context'],

	);

	require_both '__queries';

	$_REQUEST {__allow_check___query} = 1;

	check___query ();

	$_REQUEST {__allow_check___query} = 0;

	$_REQUEST {type} = $page -> {type} = '__queries';

	$_REQUEST {id}   = $_REQUEST {id___query};

	eval { $_REQUEST {__page_content} = $page -> {content} = call_for_role ('get_item_of___queries', $page -> {content}) };

	$@ and return $_REQUEST {error} = $@;

	delete $_REQUEST {__skin};

}

################################################################################

sub fix___query {

	$conf -> {core_store_table_order} or return;

	$_REQUEST {__order_context} ||= '';

	@_ORDER > 0 or return;

	if ($_REQUEST {id___query}) {

		my $is_there_some_order;

		foreach my $o (@_ORDER) {

			next unless ($o -> {order} || $o -> {no_order});

			$is_there_some_order ||= $_QUERY -> {content} -> {columns} -> {$o -> {order} || $o -> {no_order}} -> {ord};

			foreach my $filter (@{$o -> {filters}}) {

				$_QUERY -> {content} -> {filters} -> {$filter -> {name}} = $_REQUEST {$filter -> {name}};

			}

		}

		$is_there_some_order or return;

		my $id___query = $_REQUEST {id___query};

		$_REQUEST {id___query} = sql_select_id (

			$conf -> {systables} -> {__queries} => {

				fake		=> 0,
				id_user		=> $_USER -> {id},
				type		=> $_REQUEST {type},
				-dump		=> Dumper ($_QUERY -> {content}),
				label		=> '',
				order_context	=> $_REQUEST {__order_context},

			}, ['id_user', 'type', 'label', 'order_context'],

		);

		!$id___query or $_REQUEST {id___query} == $id___query or sql_do ("UPDATE $conf->{systables}->{__queries} SET parent = ? WHERE id = ?", $id___query, $_REQUEST {id___query});

	}
	else {

		my $content = {filters => {}, columns => {}};

		my %n;

		foreach my $o (@_ORDER) {

			next unless ($o -> {order} || $o -> {no_order} || $o -> {parent} -> {order} || $o -> {parent} -> {no_order});

			my $parent = exists $o -> {parent} ? ($o -> {parent} -> {order} || $o -> {parent} -> {no_order}) : '';
			$content -> {columns} -> {$o -> {order} || $o -> {no_order}} = {ord => ++ $n {$parent}};

			foreach my $filter (@{$o -> {filters}}) {

				$content -> {filters} -> {$filter -> {name}} = $_REQUEST {$filter -> {name}};

			}

		}

		$_REQUEST {id___query} = sql_select_id (

			$conf -> {systables} -> {__queries} => {

				fake        => 0,
				id_user     => $_USER -> {id},
				type        => $_REQUEST {type},
				-dump       => Dumper ($content),
				label       => '',
				order_context		=> $_REQUEST {__order_context},

			}, ['id_user', 'type', 'label', 'order_context'],

		);

	}

}

################################################################################

sub check___query {

	return if $_QUERY;

	$_REQUEST {__allow_check___query} or return;

	$conf -> {core_store_table_order} or return;

	local $_REQUEST {__the_table} = $_REQUEST {__the_table};

	$_REQUEST {__order_context} ||= '';

	if ($_REQUEST {id___query} == -1) {

		if ($SQL_VERSION -> {driver} eq 'Oracle') {
			sql_do ("DELETE FROM $conf->{systables}->{__queries} WHERE fake = 0 AND label IS NULL AND id_user = ? AND type = ? AND order_context" . ($_REQUEST {__order_context} ? ' = ?' : ' IS NULL'), $_USER -> {id}, $_REQUEST {type}, $_REQUEST {__order_context} || ());
		} else {
			sql_do ("DELETE FROM $conf->{systables}->{__queries} WHERE fake = 0 AND label = '' AND id_user = ? AND type = ? AND order_context = ?", $_USER -> {id}, $_REQUEST {type}, $_REQUEST {__order_context});
		}

	}
	else {

		if ($SQL_VERSION -> {driver} eq 'Oracle') {
			$_REQUEST {id___query} ||= sql_select_scalar ("SELECT id FROM $conf->{systables}->{__queries} WHERE fake = 0 AND label IS NULL AND id_user = ? AND type = ? AND order_context" . ($_REQUEST {__order_context} ? ' = ?' : ' IS NULL'), $_USER -> {id}, $_REQUEST {type}, $_REQUEST {__order_context} || ());
		} else {
			$_REQUEST {id___query} ||= sql_select_scalar ("SELECT id FROM $conf->{systables}->{__queries} WHERE fake = 0 AND label = '' AND id_user = ? AND type = ? AND order_context = ?", $_USER -> {id}, $_REQUEST {type}, $_REQUEST {__order_context});
		}

	}

	unless ($_REQUEST {id___query}) {

		our $_QUERY = {};
		our @_COLUMNS = ();
		return;

	}

	our $_QUERY = sql_select_hash ($conf -> {systables} -> {__queries} => $_REQUEST {id___query});

	if ($_QUERY -> {label}) {

		$_REQUEST {id___query} = sql_select_id (

			$conf -> {systables} -> {__queries} => {

				id_user		=> $_USER -> {id},
				type		=> $_QUERY -> {type},
				label		=> '',
				order_context	=> $_REQUEST {__order_context},
				-fake		=> 0,
				-dump		=> $_QUERY -> {dump},
				-parent		=> $_QUERY -> {id},

			}, ['id_user', 'type', 'label', 'order_context'],

		);

	}

	$_QUERY = sql_select_hash (<<EOS, $_REQUEST {id___query});
		SELECT
			q.*
			, p.label AS parent_label
		FROM
			$conf->{systables}->{__queries} AS q
			LEFT JOIN $conf->{systables}->{__queries} AS p ON q.parent = p.id
		WHERE
			q.id = ?
EOS

	my $VAR1;

	eval $_QUERY -> {dump};

	$_QUERY -> {content} = $VAR1;

	my $filters = $_QUERY -> {content} -> {filters};

	foreach my $key (keys %$filters) {

		next if exists $_REQUEST {$key};

		if ($key =~ /^id_/) {

			$filters -> {$key} = $_USER -> {id} if $filters -> {$key} eq '$_USER -> {id}';

		}
		elsif ($key =~ /^dt_/ && $filters -> {$key} =~ /[^\d\.]/) {

			my ($y, $m, $d) = Date::Calc::Today;

			my $q = sprintf ('%02d', $m - (($m - 1) % 3));
			$m = sprintf ('%02d', $m);
			$d = sprintf ('%02d', $d);

			$filters -> {$key} =~ s|$i18n->{reduction_year}|$y|;
			$filters -> {$key} =~ s|$i18n->{reduction_month}|$m|;
			$filters -> {$key} =~ s|$i18n->{reduction_quarter}|$q|;
			$filters -> {$key} =~ s|$i18n->{reduction_day}|$d|;

		}

		$_REQUEST {$key} = $filters -> {$key};

	}

	my $is_there_some_columns;

	foreach my $key (keys %{$_QUERY -> {content} -> {columns}}) {

		if ($_QUERY -> {content} -> {columns} -> {$key} -> {ord}) {
			$is_there_some_columns = 1;
			last;
		}

	}

	unless ($is_there_some_columns) {

		sql_do ("DELETE FROM $conf->{systables}->{__queries} WHERE id = ?", $_REQUEST {id___query});

		delete $_REQUEST {id___query};

		$_QUERY = undef;

	}

}

################################################################################

sub get_item_of___queries {

	my ($data) = @_;

	delete $_REQUEST {__read_only};

	return $data;

}

################################################################################

sub do_drop_filters___queries {

	my $_QUERY = sql_select_hash ($conf -> {systables} -> {__queries} => $_REQUEST {id});

	my $VAR1;

	eval $_QUERY -> {dump};

	$_QUERY -> {content} = $VAR1;

	delete $_QUERY -> {content} -> {filters};

	sql_do ("UPDATE $conf->{systables}->{__queries} SET dump = ? WHERE id = ?", Dumper ($_QUERY -> {content}), $_REQUEST {id});

	my $esc_href = esc_href ();

	foreach my $key (keys %_REQUEST) {

		$key =~ /^_filter_(.+)$/ or next;

		my $filter = $1;

		$filter =~ s/_\d+//;

		$esc_href =~ s/([\?\&]$filter=)[^\&]*//;

	}

	$esc_href =~ s/([\?\&]__last_query_string=)(\-?\d+)/$1$_REQUEST{__last_query_string}/;
	$esc_href .= '&__edit_query=1';

	redirect ($esc_href, {kind => 'js'});


}

################################################################################

sub do_update___queries {

	my $content = {};

	my @order = ();

	foreach my $key (keys %_REQUEST) {

		$key =~ /^_(.+)_ord$/ or next;

		my $order = $1;

		my $mandatory_field_label = $_REQUEST {"_${order}_mandatory"};

		if (!exists($_REQUEST{"_${order}_parent"}) || $_REQUEST{$_REQUEST {"_${order}_parent"}} > 0) {
			!$mandatory_field_label or $_REQUEST {"_${order}_ord"}
				or croak "#_${order}_ord#:$i18n->{column} \"$mandatory_field_label\" $i18n->{mandatory_f}";
		};

		$content -> {columns} -> {$order} = {
			ord  => $_REQUEST {"_${order}_ord"},
			sort => $_REQUEST {"_${order}_sort"},
			desc => $_REQUEST {"_${order}_desc"},
		};

		if ($_REQUEST {"_${order}_sort"}) {

			$order [ $_REQUEST {"_${order}_sort"} ]  = $order;
			$order [ $_REQUEST {"_${order}_sort"} ] .= ' DESC' if $_REQUEST {"_${order}_desc"};

		}

	}

	$content -> {order} = join ', ', grep { $_ } @order;

	foreach my $cbx (split /,/, $_REQUEST {__form_checkboxes_custom}) {
		if ($cbx =~ /(\d+)_(\d+)$/) {
			$content -> {filters} -> {$1} .= '';
		}
	}

	foreach my $key (keys %_REQUEST) {

		$key =~ /^_filter_(.+)$/ or next;

		my $filter = $1;

		$_REQUEST {$key} = join ',', -1, @{$_REQUEST {$key}} if (ref $_REQUEST {$key} eq ARRAY);

		$content -> {filters} -> {$filter} = $_REQUEST {$key} || '';

	}

	sql_do ("UPDATE $conf->{systables}->{__queries} SET dump = ? WHERE id = ?", Dumper ($content), $_REQUEST {id});

	my $esc_href = esc_href ();

	foreach my $filter (keys (%{$content -> {filters}})) {

		next
			if $filter =~ /^.+\[\]$/;

		unless ($esc_href =~ s/([\?\&]$filter=)[^\&]*/$1$content->{filters}->{$filter}/) {

			$esc_href .= "&$filter=$content->{filters}->{$filter}";

		};

	}

	$esc_href =~ s/\bstart=\d+\&?//;

	redirect ($esc_href, {kind => 'js'});

}

################################################################################

sub get___query_settings {

	my ($id_query) = @_;

	my $query = sql_select_hash ($conf -> {systables} -> {__queries} => $id_query);

	my $VAR1;
	eval $query -> {dump};

	return $VAR1;
}

################################################################################

sub set___query_settings {

	my ($id_query, $settings) = @_;

	$id_query or return;

	sql_do (
		"UPDATE $conf->{systables}->{__queries} SET dump = ? WHERE id = ?"
		, Dumper ($settings)
		, $id_query
	);
}

################################################################################

sub set_column_props {

	my ($options) = @_;

	$options -> {id_query} or return;

	my $settings = get___query_settings ($options -> {id_query});

	foreach my $key (keys %$options) {
		next if $key =~ /^id/;
		$settings -> {columns} -> {$options -> {id}} -> {$key} = $options -> {$key};
	}

	set___query_settings ($options -> {id_query}, $settings);
}

################################################################################

sub draw_item_of___queries {

	my ($data) = @_;

	my @fields = (

		{
			type  => 'banner',
			label => $i18n -> {columns_and_filters},
		},

	);

	$_REQUEST {__form_checkboxes_custom} = '';

	my $cells_cnt = [];
	my $composite_columns_cnt = -1;

	for (my $i = 0; $i < @_ORDER; $i++) {

		my $o = $_ORDER [$i];

		$o -> {order} ||= $o -> {no_order};

		next unless ($o -> {order} || $o -> {no_order});

		next
			if $o -> {__hidden} || $o -> {hidden};

		if ($_ORDER [$i - 1] -> {colspan}) {

			push @$cells_cnt, $_ORDER [$i - 1] -> {colspan};

			if ($cells_cnt -> [$composite_columns_cnt + 1]) {

				$composite_columns_cnt++;

			}

		}

		my @f;

		if (exists $o -> {type} && $o -> {type} eq 'banner') {

			@f = (
				{
					type   => 'banner',
					label  => $o -> {title} || $o -> {label},
				}
			);

		} else {

			if ($cells_cnt -> [$composite_columns_cnt]) {

				for (my $j = 0; $j <= $composite_columns_cnt; $j++) {
					push @f, {
						type => 'static',
						label_off => 1,
					};
				}

				unless ($o -> {colspan}) {
					for (my $i = 0; $i < @$cells_cnt; $i++) {
						$cells_cnt -> [$i]--;
					}
				}

				while ($cells_cnt -> [$composite_columns_cnt] == 0 && $composite_columns_cnt >= 0) {
					$composite_columns_cnt--;
					pop @$cells_cnt;
				}

			}

			push @f, (
				{
					label 		=> $o -> {title} || $o -> {label},
					type  		=> 'hgroup',
					nobr		=> 1,
					cell_width	=> '50%',
					items => [
						{
							label => $i18n -> {column_order},
							size  => 2,
							name  => $o -> {order} . '_ord',
							value => $_QUERY -> {content} -> {columns} -> {$o -> {order}} -> {ord},
							off   => $o -> {no_column},
						},
						{
							label => $i18n -> {sorting},
							size  => 2,
							name  => $o -> {order} . '_sort',
							value => $_QUERY -> {content} -> {columns} -> {$o -> {order}} -> {sort},
							off   => $o -> {no_column} || $o -> {no_order},
						},
						{
							name  => $o -> {order} . '_desc',
							type  => 'select',
							values => [{id => 1, label => $i18n -> {descending}}],
							empty => $i18n -> {ascending},
							value => $_QUERY -> {content} -> {columns} -> {$o -> {order}} -> {desc},
							off   => $o -> {no_column} || $o -> {no_order},
						},
						{
							name  => $o -> {order} . '_mandatory',
							type  => 'hidden',
							value => $o -> {title} || $o -> {label},
							off   => $o -> {no_column} || $o -> {no_order} || !$o -> {mandatory},
						},
						{
							name  => $o -> {order} . '_parent',
							type  => 'hidden',
							value => "_$o->{parent}->{order}_ord",
							off   => $o -> {no_column} || $o -> {no_order} || !$o -> {mandatory} || !$o->{parent}->{order},
						},
						{
							type  => 'static',
							value => '',
							off   => !$o -> {no_column},
						},
					],
				},
			);

			foreach my $filter (@{$o -> {filters}}) {

				my %f = %$filter;

				$f {value} ||= $_QUERY -> {content} -> {filters} -> {$f {name}};

				delete $f {type}
					if $f {type} eq 'input_text';

				$f {type} =~ s/^input_//;

				if ($f {type} eq 'select') {
					$f {values} = [grep {$_ -> {id} != -1} @{$f {values}}];
					if ($f {other}) {
						$f {name} = '_' . $f {name};
						$f {value} ||= $_QUERY -> {content} -> {filters} -> {$f {name}};
					}
				} elsif ($f {type} eq 'date') {
					$f {no_read_only}	= 1;
				} elsif ($f {type} eq 'checkbox') {
					$f {checked} = $f {value};
				} elsif ($f {type} eq 'radio') {
					$data -> {"filter_$f{name}"} = $f {value};
				} elsif ($f {type} eq 'checkboxes') {
					$data -> {'filter_' . $f {name}} = [split /,/, $f {value}];
					delete $f {value};

					$_REQUEST {__form_checkboxes_custom} .= ',' . join ',', map {"_$f{name}_$_->{id}"} @{$f {values}};
				}

				$f {name} = 'filter_' . $f {name};

				push @f, \%f;

			}

		}

		push @fields, \@f;

	}

	return draw_form ({
			keep_params	=> ['__form_checkboxes_custom'],
			right_buttons => [
				{
					icon	=> 'delete',
					label	=> $i18n -> {drop_filters},
					href	=> "javaScript:document.form.action.value='drop_filters'; \$(document.form).submit(); void(0);",
					target	=> 'invisible',
					keep_esc	=> 1,
					off		=> $_REQUEST {__read_only} || !keys %{$_QUERY -> {content} -> {filters}},
				},
			],
			no_edit => $_REQUEST {'__page_content'} -> {no_del},
			confirm_ok => undef,
		},

		$data,

		\@fields

	);

}

1;