import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:stickeep_app/screens/admin/user_reservations_screen.dart';
import 'package:stickeep_app/theme/app_theme.dart';
import 'package:stickeep_app/utils/page_route.dart';
import 'package:stickeep_app/widgets/loading_skeleton.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: const Text('Search users'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or student ID',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AdminListSkeleton();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No users found',
                        style: AppTextStyles.cardSubtitle),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  if (_query.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final studentNumber =
                      (data['studentNumber'] ?? '').toString().toLowerCase();
                  return name.contains(_query) ||
                      studentNumber.contains(_query);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text('No matching users',
                        style: AppTextStyles.cardSubtitle),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final email = data['email'] ?? '';
                    final studentNumber = data['studentNumber'] ?? '';
                    final role = data['role'] ?? 'student';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        tileColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AppColors.border),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.purpleLight,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: AppColors.purple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          'ID: $studentNumber  ·  $email',
                          style: AppTextStyles.label,
                        ),
                        trailing: role == 'admin'
                            ? StatusTag(
                                label: 'Admin',
                                backgroundColor: AppColors.purpleLight,
                                textColor: AppColors.purple,
                              )
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          AppPageRoute(
                            builder: (_) => UserReservationsScreen(
                              uid: doc.id,
                              userName: name,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
