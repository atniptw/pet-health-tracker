import '../../data/household.dart';

/// A member of a household, with their name if they have given one.
typedef HouseholdMember = ({String uid, String? name});

/// Shown for a member who hasn't given their name in the household.
const noNameYet = 'No name yet';

/// [household]'s members with their [names], named members by name and
/// then members with no name yet, leaving out [except].
List<HouseholdMember> sortedMembers(
  Household household,
  Map<String, String> names, {
  String? except,
}) {
  return [
    for (final uid in household.memberIds)
      if (uid != except) (uid: uid, name: names[uid]),
  ]..sort(_byName);
}

int _byName(HouseholdMember a, HouseholdMember b) {
  if (a.name == null || b.name == null) return a.name == null ? (b.name == null ? 0 : 1) : -1;
  return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
}
