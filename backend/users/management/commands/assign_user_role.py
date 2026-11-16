from django.core.management.base import BaseCommand, CommandError

from users.models import Role, User


class Command(BaseCommand):
    help = 'Assign an existing user to a database-defined role.'

    def add_arguments(self, parser):
        parser.add_argument('email')
        parser.add_argument('role')

    def handle(self, *args, **options):
        try:
            user = User.objects.get(email=options['email'].strip().lower())
        except User.DoesNotExist as error:
            raise CommandError('No user exists with that email address.') from error
        try:
            role = Role.objects.get(name=options['role'])
        except Role.DoesNotExist as error:
            raise CommandError('No role exists with that name.') from error

        user.role = role
        user.save(update_fields=['role'])
        self.stdout.write(self.style.SUCCESS(f'Assigned {user.email} to {role.name}.'))
